
package com.example.mobile_app

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ExperimentDiscovery(
    context: Context
) : MethodChannel.MethodCallHandler {

    private val nsd = context.getSystemService(
        Context.NSD_SERVICE
    ) as NsdManager

    private val handler = Handler(Looper.getMainLooper())

    private val serviceType = "_sctexperiment._udp."

    private var registration:
        NsdManager.RegistrationListener? = null

    private var discovery:
        NsdManager.DiscoveryListener? = null

    private val services =
        mutableMapOf<String, Map<String, Any>>()

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "startHosting" -> {
                val name = call.argument<String>("name")
                    ?: "SCT Experiment"

                val port = call.argument<Int>("port")
                    ?: 5001

                startHosting(name, port, result)
            }

            "stopHosting" -> {
                stopHosting()
                result.success(null)
            }

            "startDiscovery" -> {
                startDiscovery(result)
            }

            "getExperiments" -> {
                result.success(
                    synchronized(services) {
                        services.values.toList()
                    }
                )
            }

            "stopDiscovery" -> {
                stopDiscovery()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun startHosting(
        name: String,
        port: Int,
        result: MethodChannel.Result
    ) {
        if (registration != null) {
            result.error(
                "ALREADY_HOSTING",
                "A service is already registered",
                null
            )
            return
        }

        val info = NsdServiceInfo().apply {
            serviceName = name
            serviceType = this@ExperimentDiscovery.serviceType
            setPort(port)
        }

        val listener =
            object : NsdManager.RegistrationListener {

                override fun onServiceRegistered(
                    info: NsdServiceInfo
                ) {
                    result.success(info.serviceName)
                }

                override fun onRegistrationFailed(
                    info: NsdServiceInfo,
                    errorCode: Int
                ) {
                    registration = null
                    result.error(
                        "HOST_FAILED",
                        "NSD registration failed: $errorCode",
                        null
                    )
                }

                override fun onServiceUnregistered(
                    info: NsdServiceInfo
                ) {}

                override fun onUnregistrationFailed(
                    info: NsdServiceInfo,
                    errorCode: Int
                ) {}
            }

        registration = listener

        try {
            nsd.registerService(
                info,
                NsdManager.PROTOCOL_DNS_SD,
                listener
            )
        } catch (e: Exception) {
            registration = null
            result.error(
                "HOST_FAILED",
                e.message,
                null
            )
        }
    }

    private fun stopHosting() {
        registration?.let {
            try {
                nsd.unregisterService(it)
            } catch (_: Exception) {}
        }
        registration = null
    }

    private fun startDiscovery(
        result: MethodChannel.Result
    ) {
        if (discovery != null) {
            result.success(null)
            return
        }

        synchronized(services) {
            services.clear()
        }

        val listener =
            object : NsdManager.DiscoveryListener {

                override fun onDiscoveryStarted(
                    type: String
                ) {
                    result.success(null)
                }

                override fun onStartDiscoveryFailed(
                    type: String,
                    errorCode: Int
                ) {
                    discovery = null
                    result.error(
                        "DISCOVERY_FAILED",
                        "Discovery failed: $errorCode",
                        null
                    )
                }

                override fun onStopDiscoveryFailed(
                    type: String,
                    errorCode: Int
                ) {}

                override fun onDiscoveryStopped(
                    type: String
                ) {}

                override fun onServiceFound(
                    info: NsdServiceInfo
                ) {
                    if (!info.serviceType
                            .startsWith("_sctexperiment._udp")) {
                        return
                    }

                    @Suppress("DEPRECATION")
                    nsd.resolveService(
                        info,
                        object : NsdManager.ResolveListener {

                            override fun onResolveFailed(
                                serviceInfo: NsdServiceInfo,
                                errorCode: Int
                            ) {}

                            override fun onServiceResolved(
                                serviceInfo: NsdServiceInfo
                            ) {
                                val address =
                                    serviceInfo.host?.hostAddress
                                        ?: return

                                synchronized(services) {
                                    services[serviceInfo.serviceName] =
                                        mapOf(
                                            "name" to
                                                serviceInfo.serviceName,
                                            "host" to address,
                                            "port" to
                                                serviceInfo.port
                                        )
                                }
                            }
                        }
                    )
                }

                override fun onServiceLost(
                    info: NsdServiceInfo
                ) {
                    synchronized(services) {
                        services.remove(info.serviceName)
                    }
                }
            }

        discovery = listener

        try {
            nsd.discoverServices(
                serviceType,
                NsdManager.PROTOCOL_DNS_SD,
                listener
            )
        } catch (e: Exception) {
            discovery = null
            result.error(
                "DISCOVERY_FAILED",
                e.message,
                null
            )
        }
    }

    private fun stopDiscovery() {
        discovery?.let {
            try {
                nsd.stopServiceDiscovery(it)
            } catch (_: Exception) {}
        }

        discovery = null

        synchronized(services) {
            services.clear()
        }
    }

    fun dispose() {
        stopDiscovery()
        stopHosting()
    }
}
