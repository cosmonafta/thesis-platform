package com.example.mobile_app

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.util.ArrayDeque

/**
 * NSD/mDNS experiment discovery.
 *
 * Improvements for older Android devices:
 * - Hold a Wi-Fi multicast lock while browsing.
 * - Resolve discovered services one at a time (older NSD stacks cannot
 *   reliably process multiple simultaneous resolveService requests).
 * - Retry failed resolutions and log failures rather than silently ignoring them.
 * - Prefer IPv4 addresses because the Dart join socket is IPv4-only.
 */
class ExperimentDiscovery(context: Context) : MethodChannel.MethodCallHandler {
    private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val handler = Handler(Looper.getMainLooper())
    private val serviceType = "_sctexperiment._udp."

    private var registration: NsdManager.RegistrationListener? = null
    private var discovery: NsdManager.DiscoveryListener? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    private val services = mutableMapOf<String, Map<String, Any>>()
    private val pendingResolutions = ArrayDeque<NsdServiceInfo>()
    private val pendingNames = mutableSetOf<String>()
    private val lostNames = mutableSetOf<String>()
    private var resolving = false
    private var resolveGeneration = 0
    private var discoveryGeneration = 0
    private var discoveryStartResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startHosting" -> {
                val name = call.argument<String>("name") ?: "SCT Experiment"
                val port = call.argument<Int>("port") ?: 5001
                startHosting(name, port, result)
            }
            "stopHosting" -> {
                stopHosting()
                result.success(null)
            }
            "startDiscovery" -> startDiscovery(result)
            "getExperiments" -> result.success(synchronized(services) { services.values.toList() })
            "stopDiscovery" -> {
                stopDiscovery()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startHosting(name: String, port: Int, result: MethodChannel.Result) {
        if (registration != null) {
            result.error("ALREADY_HOSTING", "A service is already registered", null)
            return
        }
        val info = NsdServiceInfo().apply {
            serviceName = name
            serviceType = this@ExperimentDiscovery.serviceType
            setPort(port)
        }
        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) {
                Log.i(TAG, "Registered ${info.serviceName} on port ${info.port}")
                result.success(info.serviceName)
            }
            override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                registration = null
                result.error("HOST_FAILED", "NSD registration failed: $errorCode", null)
            }
            override fun onServiceUnregistered(info: NsdServiceInfo) {}
            override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                Log.w(TAG, "Unregistration failed: $errorCode")
            }
        }
        registration = listener
        try {
            nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, listener)
        } catch (e: Exception) {
            registration = null
            result.error("HOST_FAILED", e.message, null)
        }
    }

    private fun stopHosting() {
        registration?.let {
            try { nsd.unregisterService(it) } catch (e: Exception) {
                Log.w(TAG, "Unable to unregister NSD service", e)
            }
        }
        registration = null
    }

    private fun acquireMulticastLock() {
        if (multicastLock != null) return
        try {
            val lock = wifi.createMulticastLock("sct-experiment-nsd")
            lock.setReferenceCounted(false)
            lock.acquire()
            multicastLock = lock
            Log.i(TAG, "Wi-Fi multicast lock acquired")
        } catch (e: Exception) {
            Log.w(TAG, "Could not acquire multicast lock; check CHANGE_WIFI_MULTICAST_STATE", e)
        }
    }

    private fun releaseMulticastLock() {
        try { multicastLock?.release() } catch (e: Exception) {
            Log.w(TAG, "Unable to release multicast lock", e)
        }
        multicastLock = null
    }

    private fun startDiscovery(result: MethodChannel.Result) {
        if (discovery != null) {
            result.success(null)
            return
        }
        synchronized(services) { services.clear() }
        pendingResolutions.clear()
        pendingNames.clear()
        lostNames.clear()
        resolving = false
        discoveryGeneration++
        val generation = discoveryGeneration
        acquireMulticastLock()
        discoveryStartResult = result

        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(type: String) {
                Log.i(TAG, "Discovery started for $type")
                if (discoveryGeneration == generation) {
                    discoveryStartResult?.success(null)
                    discoveryStartResult = null
                }
            }
            override fun onStartDiscoveryFailed(type: String, errorCode: Int) {
                Log.e(TAG, "Discovery start failed: $errorCode")
                if (discoveryGeneration == generation) {
                    discovery = null
                    releaseMulticastLock()
                    discoveryStartResult?.error("DISCOVERY_FAILED", "Discovery failed: $errorCode", null)
                    discoveryStartResult = null
                }
            }
            override fun onStopDiscoveryFailed(type: String, errorCode: Int) {
                Log.w(TAG, "Discovery stop failed: $errorCode")
            }
            override fun onDiscoveryStopped(type: String) {
                Log.i(TAG, "Discovery stopped for $type")
            }
            override fun onServiceFound(info: NsdServiceInfo) {
                if (discoveryGeneration != generation) return
                if (!info.serviceType.startsWith("_sctexperiment._udp")) return
                Log.i(TAG, "Found NSD service: ${info.serviceName}")
                lostNames.remove(info.serviceName)
                enqueueResolution(info, generation)
            }
            override fun onServiceLost(info: NsdServiceInfo) {
                if (discoveryGeneration != generation) return
                Log.i(TAG, "Lost NSD service: ${info.serviceName}")
                lostNames.add(info.serviceName)
                synchronized(services) { services.remove(info.serviceName) }
                pendingResolutions.removeAll { it.serviceName == info.serviceName }
                pendingNames.remove(info.serviceName)
            }
        }
        discovery = listener
        try {
            nsd.discoverServices(serviceType, NsdManager.PROTOCOL_DNS_SD, listener)
        } catch (e: Exception) {
            discovery = null
            discoveryStartResult = null
            releaseMulticastLock()
            result.error("DISCOVERY_FAILED", e.message, null)
        }
    }

    private fun enqueueResolution(info: NsdServiceInfo, generation: Int) {
        if (!pendingNames.add(info.serviceName)) return
        pendingResolutions.addLast(info)
        resolveNext(generation)
    }

    private fun resolveNext(generation: Int) {
        if (discoveryGeneration != generation || resolving) return
        if (pendingResolutions.isEmpty()) return
        val info = pendingResolutions.removeFirst()
        resolving = true
        val attemptGeneration = ++resolveGeneration
        var finished = false

        fun finish() {
            if (finished) return
            finished = true
            pendingNames.remove(info.serviceName)
            resolving = false
            handler.post { resolveNext(generation) }
        }

        val timeout = Runnable {
            if (discoveryGeneration == generation && resolveGeneration == attemptGeneration && !finished) {
                Log.w(TAG, "NSD resolve timed out: ${info.serviceName}")
                finish()
            }
        }
        handler.postDelayed(timeout, 6000)
        try {
            @Suppress("DEPRECATION")
            nsd.resolveService(info, object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                    handler.removeCallbacks(timeout)
                    Log.w(TAG, "Resolve failed for ${info.serviceName}: $errorCode")
                    if (discoveryGeneration == generation && resolveGeneration == attemptGeneration) finish()
                }
                override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                    handler.removeCallbacks(timeout)
                    if (discoveryGeneration != generation || resolveGeneration != attemptGeneration || finished) return
                    val address = serviceInfo.host
                    if (address is Inet4Address && !lostNames.contains(info.serviceName)) {
                        synchronized(services) {
                            services[info.serviceName] = mapOf(
                                "name" to serviceInfo.serviceName,
                                "host" to address.hostAddress,
                                "port" to serviceInfo.port
                            )
                        }
                        Log.i(TAG, "Resolved ${info.serviceName} -> ${address.hostAddress}:${serviceInfo.port}")
                    } else {
                        Log.w(TAG, "NSD returned no IPv4 address for ${info.serviceName}: $address")
                    }
                    finish()
                }
            })
        } catch (e: Exception) {
            handler.removeCallbacks(timeout)
            Log.w(TAG, "resolveService threw for ${info.serviceName}", e)
            finish()
        }
    }

    private fun stopDiscovery() {
        discoveryGeneration++
        discoveryStartResult?.error("DISCOVERY_STOPPED", "Discovery stopped before starting", null)
        discoveryStartResult = null
        discovery?.let {
            try { nsd.stopServiceDiscovery(it) } catch (e: Exception) {
                Log.w(TAG, "Unable to stop NSD discovery", e)
            }
        }
        discovery = null
        pendingResolutions.clear()
        pendingNames.clear()
        lostNames.clear()
        resolving = false
        synchronized(services) { services.clear() }
        releaseMulticastLock()
    }

    fun dispose() {
        stopDiscovery()
        stopHosting()
    }

    companion object {
        private const val TAG = "ExperimentDiscovery"
    }
}
