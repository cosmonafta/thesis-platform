import '../models/conversation_scenario.dart';

const List<ConversationScenario> conversationScenarios = [

  // ============================================================
  // SCENARIO 1
  // ============================================================

  ConversationScenario(
    id: 1,
    title: 'British Rail Travel Information',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Thompson',

      task:
          'Find a suitable train connection from London King\'s Cross '
          'to Inverness.',

      conditions: [
        'Date: July 20th',
        'Night train connection',
        'Sleeper required',
        'Through train if possible',
      ],

      informationToFind: [
        'Departure time',
        'Arrival time',
        'Train number',
      ],

      informationToProvide: [
        'Reservation: one berth in a sleeping-car',
        'First class',
        'Non-smoker',
      ],

      discussionQuestion:
          'What time does the buffet car start serving breakfast?',
    ),

    receiver: ConversationRole(
      roleName: 'British Rail Travel Service',
      participantName: 'British Rail Travel Service',

      task:
          'Help the caller find a suitable train connection '
          'from London King\'s Cross to Inverness.',

      informationToProvide: [
        'IC 1127: London King\'s Cross 19:18 → Inverness 04:39. '
            'Sleeper only 2nd class.',

        'IC 829 / EN 225: London King\'s Cross 20:50 → York 21:49. '
            'EN 225 leaves York at 22:44 and arrives Inverness at 06:30. '
            'Sleeper only 2nd class.',

        'IC 1511: London King\'s Cross 22:09 → Inverness 07:16. '
            'Sleeper 1st and 2nd class.',
      ],

      informationToFind: [
        'Name',
        'Number of berths',
        'Class',
        'Smoker / non-smoker',
      ],

      discussionQuestion:
          'What time does the buffet car start serving breakfast?',
    ),
  ),

  // ============================================================
  // SCENARIO 2
  // ============================================================

  ConversationScenario(
    id: 2,
    title: 'British Rail Travel Information',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Hill',

      task:
          'Find a suitable train connection from London Euston '
          'to Carlisle.',

      conditions: [
        'Date: October 5th',
        'Arrival between 16:00 and 16:30',
      ],

      informationToFind: [
        'Departure time',
        'Where to change',
        'Time of change',
        'Arrival time',
      ],

      informationToProvide: [
        'Reservation: 2 seats',
        'Second class',
        'Non-smoker',
      ],

      discussionQuestion:
          'Is there enough time to change?',
    ),

    receiver: ConversationRole(
      roleName: 'British Rail Travel Service',
      participantName: 'British Rail Travel Service',

      task:
          'Help the caller find a suitable London Euston–Carlisle '
          'connection.',

      informationToProvide: [
        'IC 645: London Euston 09:27 → Crewe 11:05.',
        'IC 2341: Crewe 11:20 → Carlisle 14:01.',

        'IC 506: London Euston 11:27 → Crewe 13:35.',
        'IC 2343: Crewe 13:47 → Carlisle 16:01.',

        'IC 941: London Euston 14:28 → Carlisle 18:51.',
      ],

      informationToFind: [
        'Name',
        'Number of seats',
        'Class',
        'Smoker / non-smoker',
      ],

      discussionQuestion:
          'Is there enough time to change?',
    ),
  ),

  // ============================================================
  // SCENARIO 3
  // ============================================================

  ConversationScenario(
    id: 3,
    title: 'Information on Flights',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Parker',

      task:
          'Find a flight from London Heathrow to Düsseldorf.',

      conditions: [
        'Date: June 23rd',
        'Morning flight',
        'Direct flight preferred',
      ],

      informationToFind: [
        'Departure time',
        'Arrival time',
        'Flight number',
      ],

      informationToProvide: [
        'Reservation: one seat',
        'Economy Class',
        'Address: 47 Industry Street, Sheffield',
        'Telephone number: 20833',
      ],

      discussionQuestion:
          'From which airport is it easier to get into Cologne city centre: '
          'Düsseldorf or Cologne/Bonn?',
    ),

    receiver: ConversationRole(
      roleName: 'Flight Information',
      participantName: 'Heathrow Flight Information',

      task:
          'Help the caller find a suitable flight from Heathrow '
          'to Düsseldorf.',

      informationToProvide: [
        'LH 2615: Heathrow 06:30 → Düsseldorf 07:35. Direct.',
        'BA 381: Heathrow 06:35 → Brussels 07:35; '
            'Brussels 07:50 → Düsseldorf 08:55.',
        'LH 413: Heathrow 08:20 → Düsseldorf 09:25. Direct.',
        'All listed flights operate daily.',
      ],

      informationToFind: [
        'Name',
        'Address',
        'Telephone number',
        'Number of seats',
        'Class: Business or Economy',
      ],

      discussionQuestion:
          'From which airport is it easier to get into Cologne city centre: '
          'Düsseldorf or Cologne/Bonn?',
    ),
  ),

  // ============================================================
  // SCENARIO 4
  // ============================================================

  ConversationScenario(
    id: 4,
    title: 'Information on Flights',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Kelly',

      task:
          'Find a flight from Frankfurt to New York.',

      conditions: [
        'Date: June 6th',
        'Destination: JFK airport',
      ],

      informationToFind: [
        'Departure time',
        'Stopover location, if applicable',
        'Stopover time, if applicable',
        'Arrival time',
      ],

      informationToProvide: [
        'Reservation: one seat',
        'MasterCard',
        'Credit card number: 2602 2704 1612 1807',
        'Valid till: 2/99',
      ],

      discussionQuestion:
          'What is the time difference between Frankfurt and New York? '
          'Are they ahead of us or behind?',
    ),

    receiver: ConversationRole(
      roleName: 'Flight Information',
      participantName: 'Flight Information Frankfurt Airport',

      task:
          'Help the caller find a suitable flight from Frankfurt '
          'to New York.',

      informationToProvide: [
        'LH 400: Frankfurt 09:50 → New York JFK 11:40.',
        'UA 129: Frankfurt 07:25 → London Heathrow 08:00; '
            'London Heathrow 09:15 → New York Newark 12:15.',
        'LH 402: Frankfurt 13:30 → New York 16:05.',
        'Arrival times are local times.',
      ],

      informationToFind: [
        'Name',
        'Number of seats',
        'Credit card',
        'Credit card number',
        'Valid till',
      ],

      discussionQuestion:
          'What is the time difference between Frankfurt and New York? '
          'Are they ahead of us or behind?',
    ),
  ),

  // ============================================================
  // SCENARIO 5
  // ============================================================

  ConversationScenario(
    id: 5,
    title: 'Theatre Box Office',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Richardson',

      task:
          'Buy 2 tickets for the "Three Penny Opera".',

      conditions: [
        'Next weekend: Saturday or Sunday',
        'Student reduction',
      ],

      informationToFind: [
        'Day',
        'Starting time',
        'Price',
        'Auditorium',
      ],

      informationToProvide: [
        'Reservation: two seats',
        'Middle section of the stalls',
      ],

      discussionQuestion:
          'By what time do we have to collect tickets we have reserved?',
    ),

    receiver: ConversationRole(
      roleName: 'Theatre Box Office',
      participantName: 'Palladium Theatre, London',

      task:
          'Help the caller select and reserve theatre tickets.',

      informationToProvide: [
        'Monday 20:00 – Hamlet – Main auditorium',
        'Tuesday 20:00 – Look Back in Anger – Small auditorium',
        'Tuesday 20:00 – The Crucible III – Studio',
        'Wednesday 20:00 – Romeo and Juliet – Main auditorium',
        'Thursday 20:00 – Three Penny Opera – Main auditorium',
        'Thursday 20:00 – Look Back in Anger – Small auditorium',
        'Thursday 20:00 – My Fair Lady – Studio',
        'Friday 20:15 – Hamlet – Main auditorium',
        'Friday 20:15 – The Crucible III – Studio',
        'Saturday 19:30 – Three Penny Opera – Main auditorium',
        'Saturday 19:30 – A Midsummer Night\'s Dream – Small auditorium',
        'Saturday 19:30 – My Fair Lady – Studio',
        'Sunday 19:45 – Romeo and Juliet – Main auditorium',
        'Sunday 19:45 – A Midsummer Night\'s Dream – Small auditorium',
        'Adult tickets: £5 to £20',
        'Reduced tickets: £4',
      ],

      informationToFind: [
        'Name',
        'Number of seats',
        'Price / ticket type',
        'Seats: stalls or row',
        'Seats: right or middle',
      ],

      discussionQuestion:
          'By what time do we have to collect tickets we have reserved?',
    ),
  ),

  // ============================================================
  // SCENARIO 6
  // ============================================================

  ConversationScenario(
    id: 6,
    title: 'Concert Box Office',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Dr Spencer',

      task:
          'Buy 2 tickets for Starlight Express.',

      conditions: [
        'Saturday, July 5th or Sunday, July 6th',
        'Tickets must cost less than £35',
      ],

      informationToFind: [
        'Date',
        'Time',
        'Seat category',
        'Price per ticket',
      ],

      informationToProvide: [
        'Reservation address: 12 Industry Street, London',
        'Telephone number: 47 59 40',
      ],

      discussionQuestion:
          'Will the musical be in German or in English?',
    ),

    receiver: ConversationRole(
      roleName: 'Concert Box Office',
      participantName: 'STELLA – The Musical Company',

      task:
          'Help the caller find tickets for Starlight Express.',

      informationToProvide: [
        'Saturday July 5th – 20:00',
        'Front stalls: £50 – sold out on Saturday; £37 on Sunday',
        'Dress circle: £60 – sold out on Saturday; £47 on Sunday',
        'Gallery: £60 on Saturday; £47 on Sunday – sold out on Sunday',
        'Side gallery: £40 on Saturday; £30 on Sunday',
        'Row at the rear: £30 on Saturday; £20 on Sunday – sold out on Sunday',
      ],

      informationToFind: [
        'Number of seats',
        'Name',
        'Address',
        'Telephone number',
      ],

      discussionQuestion:
          'Will the musical be in German or in English?',
    ),
  ),

  // ============================================================
  // SCENARIO 7
  // ============================================================

  ConversationScenario(
    id: 7,
    title: 'Renting a Car',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Phillips',

      task:
          'Rent one small removal van.',

      conditions: [
        'For one weekend: Saturday and Sunday',
        'At least 1.80 m headroom inside',
        'As cheap as possible',
      ],

      informationToFind: [
        'Type of van',
        'Headroom inside',
        'Price per day',
      ],

      informationToProvide: [
        'Eurocard',
        'Credit card number: 8823 7453 6592 0023',
        'Valid till: 12/99',
        'HGV driving licence',
      ],

      discussionQuestion:
          'How early can I collect the van?',
    ),

    receiver: ConversationRole(
      roleName: 'Car Rental',
      participantName: 'AVIS Car Rentals',

      task:
          'Help the caller choose and reserve a small vehicle.',

      informationToProvide: [
        'Ford Transit – HGV licence – 100 km free – £40/day – 2 m headroom',
        'Mercedes Sprinter – HGV licence – 100 km free – £60/day – 2.30 m headroom',
        'VW Transporter – HGV licence – 100 km free – £35/day – 1.90 m headroom',

        'Ford Transit booked: Monday, Tuesday, Thursday and Sunday',
        'Mercedes Sprinter booked: Monday, Tuesday, Wednesday and Friday',
        'VW Transporter booked: Wednesday and Thursday',
      ],

      informationToFind: [
        'Name',
        'Credit card',
        'Credit card number',
        'Valid till',
        'Driving licence class',
      ],

      discussionQuestion:
          'How early can I collect the van?',
    ),
  ),

  // ============================================================
  // SCENARIO 8
  // ============================================================

  ConversationScenario(
    id: 8,
    title: 'Renting a Car',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Pickering',

      task:
          'Rent a car.',

      conditions: [
        'Thursday to Saturday',
        'As cheaply as possible',
      ],

      informationToFind: [
        'Model',
        'Collection point',
        'Price per day',
      ],

      informationToProvide: [
        'American Express',
        'Credit card number: 6430 5188 1926 4623',
        'Valid till: 09/99',
      ],

      discussionQuestion:
          'Is insurance included in the price?',
    ),

    receiver: ConversationRole(
      roleName: 'Car Rental',
      participantName: 'Hertz Car Rentals',

      task:
          'Help the caller choose and reserve a car.',

      informationToProvide: [
        'VW Golf – £30/day – 300 km free – '
            'Multi-storey car park in station. '
            'Booked Wednesday, Thursday, Friday, Saturday and Sunday.',

        'Vauxhall Corsa – £25/day – 100 km free – '
            'Multi-storey car park in station. '
            'Booked Monday and Wednesday.',

        'Mercedes C 240 – £35/day – 100 km free – '
            'Car park York Street. '
            'Booked Monday, Tuesday, Wednesday and Sunday.',

        'Audi Quattro – £33/day – 100 km free – '
            'Car park York Street. '
            'Booked Monday, Tuesday and Sunday.',
      ],

      informationToFind: [
        'Name',
        'Credit card type',
        'Credit card number',
        'Valid till',
      ],

      discussionQuestion:
          'Is insurance included in the price?',
    ),
  ),

  // ============================================================
  // SCENARIO 9
  // ============================================================

  ConversationScenario(
    id: 9,
    title: 'Room Reservation',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Francis',

      task:
          'Reserve two single rooms.',

      conditions: [
        'Dates: March 16th to March 23rd',
        'With a bathroom and balcony if possible',
      ],

      informationToFind: [
        'Room number for first room',
        'Bathroom: yes/no',
        'Balcony: yes/no',
        'Room number for second room',
        'Bathroom: yes/no',
        'Balcony: yes/no',
      ],

      informationToProvide: [
        'First room for Andrew Francis',
        'Second room for Sarah Harrison',
        'Telephone number: 897126',
      ],

      discussionQuestion:
          'Is there still enough snow in March to go skiing?',
    ),

    receiver: ConversationRole(
      roleName: 'Hotel',
      participantName: 'Resort Hotel Tirol',

      task:
          'Help the caller reserve suitable rooms.',

      informationToProvide: [
        'Room 106 – Double – without bath – with balcony',
        'Room 118 – Single – with bath – with balcony',
        'Room 235 – Single – with bath – without balcony',
        'Room 257 – Double – without bath – without balcony',

        'March 1–7: Rooms 106, 118 and 235 are booked.',
        'March 8–14: Rooms 106 and 257 are booked.',
        'March 15–21: no rooms shown as booked.',
        'March 22–28: Rooms 106 and 118 are booked.',
      ],

      informationToFind: [
        'Name',
        'Telephone number',
      ],

      discussionQuestion:
          'Is there still enough snow in March to go skiing?',
    ),
  ),

  // ============================================================
  // SCENARIO 10
  // ============================================================

  ConversationScenario(
    id: 10,
    title: 'Booking an Apartment',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Dr Silversmith',

      task:
          'Book one holiday apartment in Rimini, Italy.',

      conditions: [
        'From March 24th to 31st',
        'Must sleep at least 4 people',
        'If possible, near the beach',
      ],

      informationToFind: [
        'Name of apartment',
        'Number of people it sleeps',
        'Price per week',
        'Distance from beach',
      ],

      informationToProvide: [
        'Address: 233 Middle Street, Oxford',
        'Telephone number: 75618',
      ],

      discussionQuestion:
          'Is it warm enough to go swimming in March?',
    ),

    receiver: ConversationRole(
      roleName: 'Apartment Booking',
      participantName: 'Family Club Italy',

      task:
          'Help the caller find a suitable holiday apartment.',

      informationToProvide: [
        'Calderone – 3 beds – approx. 200 m from beach – £70/week',
        'Angeli – 4 beds – approx. 50 m from beach – £120/week',
        'Pronti – 6 beds – approx. 50 m from beach – £90/week',
        'Riviera – 6 beds – approx. 50 m from beach – £180/week',

        'March 1–7: Angeli, Pronti and Riviera booked.',
        'March 8–14: Calderone, Angeli and Riviera booked.',
        'March 15–21: Calderone and Riviera booked.',
        'March 22–28: Riviera booked.',
      ],

      informationToFind: [
        'Name',
        'Address',
      ],

      discussionQuestion:
          'Is it warm enough to go swimming in March?',
    ),
  ),

  // ============================================================
  // SCENARIO 11
  // ============================================================

  ConversationScenario(
    id: 11,
    title: 'Pizza Service',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Clemence',

      task:
          'Order one large pizza.',

      conditions: [
        'For 2 people',
        'Vegetarian pizza preferred',
      ],

      informationToFind: [
        'Topping',
        'Price',
      ],

      informationToProvide: [
        'Delivery address: 109 Weather Street, Brighton',
        'Telephone number: 73420',
      ],

      discussionQuestion:
          'How long will we have to wait for the pizza to be delivered?',
    ),

    receiver: ConversationRole(
      roleName: 'Pizza Service',
      participantName: 'Pizzeria Roma',

      task:
          'Help the caller choose and order a pizza.',

      informationToProvide: [
        'Toscana – ham, mushrooms, tomatoes, cheese – '
            '£3.20 for 1 person, £5.95 for 2, £10.50 for 4.',

        'Tonno – tuna, onions, tomatoes, cheese – '
            '£3.95 for 1 person, £7.50 for 2, £13.95 for 4.',

        'Fabrizio – salami, ham, tomatoes, cheese – '
            '£4.20 for 1 person, £7.95 for 2, £14.95 for 4.',

        'Vegetarian – spinach, mushrooms, tomatoes, cheese – '
            '£4.50 for 1 person, £8.50 for 2, £15.95 for 4.',
      ],

      informationToFind: [
        'Name',
        'Address',
        'Telephone number',
      ],

      discussionQuestion:
          'How long will we have to wait for the pizza to be delivered?',
    ),
  ),

  // ============================================================
  // SCENARIO 12
  // ============================================================

  ConversationScenario(
    id: 12,
    title: 'Party Service',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Chatwin',

      task:
          'Order food for a party.',

      conditions: [
        'For 30 people',
        'As cheap as possible',
      ],

      informationToFind: [
        'Offer',
        'Portion',
        'Side dish / extra',
        'Price per person',
      ],

      informationToProvide: [
        'Delivery address: 436 Turner Street, Dover',
        'Date and time: Saturday, April 5th, 12:00',
      ],

      discussionQuestion:
          'How much beer should be ordered for 30 people?',
    ),

    receiver: ConversationRole(
      roleName: 'Party Service',
      participantName: 'Good Time Party Service Ltd.',

      task:
          'Help the caller choose food for the party.',

      informationToProvide: [
        'Warm buffet – minimum 40 people – £5/person – '
            'salads – 500 g portion.',

        'Cold buffet – minimum 30 people – £3/person – '
            'chocolate pudding – 400 g portion.',

        'Irish stew – minimum 25 people – £2/person – '
            'baguette – 350 g portion.',

        'Hotdogs – minimum 20 people – £1/person – '
            'potato salad – 300 g portion.',
      ],

      informationToFind: [
        'Name',
        'Address',
        'Number of people',
        'Day, date and time',
      ],

      discussionQuestion:
          'How much beer should be ordered for 30 people?',
    ),
  ),

  // ============================================================
  // SCENARIO 13
  // ============================================================

  ConversationScenario(
    id: 13,
    title: 'Library',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Mackintosh',

      task:
          'Borrow a book.',

      conditions: [
        'A detective novel by Agatha Christie',
        'Reserve it if it has already been taken out',
      ],

      informationToFind: [
        'Title of book',
        'Reserved until / available from',
        'Borrowing period',
      ],

      informationToProvide: [
        'Telephone number: 262271',
        'Membership number: H 1092',
      ],

      discussionQuestion:
          'How many books can I take out?',
    ),

    receiver: ConversationRole(
      roleName: 'Library',
      participantName: 'City Library',

      task:
          'Help the caller find and order a suitable book.',

      informationToProvide: [
        'Agatha Christie – Murder on the Orient Express – '
            'borrowed until Friday – lending period 10 days.',

        'Agatha Christie – Death on the Nile – '
            'borrowed until Monday – lending period 10 days.',

        'Agatha Christie – The Mouse Trap – '
            'borrowed until Tuesday – lending period 10 days.',

        'Astrid Lindgren – Pippi Longstocking – '
            'available – lending period 8 days.',

        'Astrid Lindgren – The Six Bullebly Children – '
            'borrowed until Wednesday – lending period 8 days.',

        'Michael Ende – Jim Button and Luke the Engine Driver – '
            'borrowed until Thursday – lending period 12 days.',

        'Michael Ende – Momo – available – lending period 12 days.',

        'Michael Ende – The Never-ending Story – '
            'borrowed until Friday – lending period 12 days.',
      ],

      informationToFind: [
        'Name',
        'Membership number',
        'Telephone number',
      ],

      discussionQuestion:
          'How many books can I take out?',
    ),
  ),

  // ============================================================
  // SCENARIO 14
  // ============================================================

  ConversationScenario(
    id: 14,
    title: 'Library',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Jacobs',

      task:
          'Extend the borrowing period of a book.',

      conditions: [
        '"Pippi Longstocking" by Astrid Lindgren',
        'Taken out one week ago',
        'Keep it for as long as possible',
      ],

      informationToFind: [
        'Date today',
        'Extension until',
        'Price',
      ],

      informationToProvide: [
        'Membership number: J 91 38 70',
      ],

      discussionQuestion:
          'Have you got other books by Astrid Lindgren?',
    ),

    receiver: ConversationRole(
      roleName: 'Library',
      participantName: 'City Library',

      task:
          'Determine how long the caller may extend the borrowing period.',

      informationToProvide: [
        'Biography – no extension possible',
        'Fantasy – maximum extension 7 days',
        'Horror – maximum extension 14 days',
        'Children\'s book – maximum extension 5 days',
        'Detective novel – maximum extension 7 days',
        'Reference books – no extension possible',
        'Non-fiction – maximum extension 1 month',
      ],

      informationToFind: [
        'Book title',
        'Extension until',
        'Name',
        'Membership number',
      ],

      discussionQuestion:
          'Have you got other books by Astrid Lindgren?',
    ),
  ),

  // ============================================================
  // SCENARIO 15
  // ============================================================

  ConversationScenario(
    id: 15,
    title: 'Flat to Let',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Christie',

      task:
          'Place an advertisement for a flat.',

      conditions: [
        'Section: property to let',
        'Advertisement should appear on Saturday',
        'In as prominent a place as possible',
      ],

      informationToFind: [
        'Kind of text / print style',
        'Price',
        'Who the cheque should be payable to',
      ],

      informationToProvide: [
        'Advertisement text:',
        '3 rooms, kitchen, hall, bathroom, 67 m²',
        '£250 excluding bills',
        'Available from June 7th',
        'Telephone number: 714530',
      ],

      discussionQuestion:
          'How many copies of the Evening Chronicle are sold at the weekend?',
    ),

    receiver: ConversationRole(
      roleName: 'Advertising Department',
      participantName:
          'Private Advertising Department, Evening Chronicle',

      task:
          'Help the caller place an advertisement for a flat.',

      informationToProvide: [
        'Price per line for advertisements concerning flats to let:',

        'Bold print + framed: '
            'Mon £4, Tue £4, Wed £5, Thu £4, Fri £5, Sat £6.',

        'Bold print: '
            'Mon £3, Tue £3, Wed £4, Thu £3, Fri £4, Sat £5.',

        'Normal print + framed: '
            'Mon £3, Tue £3, Wed £3, Thu £3, Fri £3, Sat £4.',

        'Normal print: '
            'Mon £2, Tue £2, Wed £2, Thu £2, Fri £2, Sat £3.',

        'Available sections: To Let, Accommodation Wanted, Miscellaneous.',
      ],

      informationToFind: [
        'Section',
        'Required print style',
        'Advertisement text',
      ],

      discussionQuestion:
          'How many copies of the Evening Chronicle are sold at the weekend?',
    ),
  ),

  // ============================================================
  // SCENARIO 16
  // ============================================================

  ConversationScenario(
    id: 16,
    title: 'Flat to Let',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Nelson',

      task:
          'Find the price and arrange an appointment to view a flat '
          'in London.',

      conditions: [
        '3 rooms, hall and bathroom',
        'Approximately 50–65 m²',
        'Viewing only possible at the weekend',
      ],

      informationToFind: [
        'Size of flat',
        'Address',
        'Viewing day and time',
        'Price',
      ],

      informationToProvide: [
        'Home telephone: 802363',
        'Office telephone: 550012',
      ],

      discussionQuestion:
          'Do I have to pay a deposit?',
    ),

    receiver: ConversationRole(
      roleName: 'Property Developer',
      participantName: 'Trandy Property Developers Ltd.',

      task:
          'Help the caller find and arrange a viewing for a suitable flat.',

      informationToProvide: [
        '2-room flat – 47 m² – 235 Parker Street – '
            'viewing next Wednesday from 17:30 – £300 excluding bills.',

        '1-room flat – 30 m² – 41 Morning Street – '
            'viewing next Friday from 18:00 – £230 excluding bills.',

        '3-room flat – 58 m² – 2 Pitt Street – '
            'viewing next Saturday from 10:00 – £340 excluding bills.',

        '3-room flat – 64 m² – 7 Flower Street – '
            'viewing next Saturday from 14:00 – £400 excluding bills.',
      ],

      informationToFind: [
        'Name',
        'Telephone number',
        'Day and time of appointment',
      ],

      discussionQuestion:
          'Do I have to pay a deposit?',
    ),
  ),

  // ============================================================
  // SCENARIO 17
  // ============================================================

  ConversationScenario(
    id: 17,
    title: 'Eye Specialist\'s Appointment',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Robinson',

      task:
          'Make an appointment with an eye specialist.',

      conditions: [
        'Wednesday or Thursday',
        'Before 09:00 if possible',
      ],

      informationToFind: [
        'Day',
        'Date',
        'Time',
      ],

      informationToProvide: [
        'Last visit: 6 months ago',
        'Reason for visit: check-up',
      ],

      discussionQuestion:
          'Will I have to wait even though I have an appointment?',
    ),

    receiver: ConversationRole(
      roleName: 'Eye Specialist Practice',
      participantName: 'Practice Dr Wilson',

      task:
          'Find a suitable free appointment for the caller.',

      informationToProvide: [
        'Appointments – first week in June:',

        'Monday 2nd: '
            '08:30 Flowers; '
            '09:00 Hill; '
            '09:15 Walsh; '
            '09:30 Sims; '
            '09:45 Reed; '
            '10:15 Collins; '
            '10:30 Sharp; '
            '10:45 Reuter.',

        'Tuesday 3rd: '
            '08:30 Sting; '
            '08:45 Marshall; '
            '09:00 Samson; '
            '09:30 King; '
            '09:45 Simons; '
            '10:00 Owry; '
            '10:15 Miller; '
            '10:30 Lambert; '
            '10:45 Debenham.',

        'Wednesday 4th: '
            '08:45 Kelly; '
            '09:00 Chapman; '
            '09:15 Coolman; '
            '09:45 Robson; '
            '10:00 Zorco; '
            '10:15 Edwards; '
            '10:30 French.',

        'Thursday 5th: '
            '08:45 Gabriel; '
            '09:00 Flintstone; '
            '09:15 Riddle; '
            '09:30 Tanko; '
            '09:45 Tretschok; '
            '10:00 Hermas; '
            '10:15 Dobson; '
            '10:45 Domingo.',

        'Friday 6th: '
            '09:00 Jackson; '
            '09:30 Grant; '
            '09:45 Bon Jovi; '
            '10:00 Bond; '
            '10:15 Clapton.',
      ],

      informationToFind: [
        'Day, date and time',
        'Has the patient been here before?',
        'When was the last visit?',
        'Reason: new glasses, check-up, or problems/pain',
      ],

      discussionQuestion:
          'Will I have to wait even though I have an appointment?',
    ),
  ),

  // ============================================================
  // SCENARIO 18
  // ============================================================

  ConversationScenario(
    id: 18,
    title: 'Eye Specialist\'s Appointment',

    caller: ConversationRole(
      roleName: 'Caller',
      participantName: 'Robson',

      task:
          'Change an existing eye specialist appointment.',

      conditions: [
        'After 17:00 if possible',
        'Any day is acceptable',
        'The appointment is only for a check-up',
      ],

      informationToFind: [
        'New appointment date',
        'New appointment time',
      ],

      informationToProvide: [
        'Old appointment: Tuesday 15:30',
        'Reason for visit: check-up',
      ],

      discussionQuestion:
          'How long does a check-up take?',
    ),

    receiver: ConversationRole(
      roleName: 'Eye Specialist Practice',
      participantName: 'Practice Dr Miller',

      task:
          'Change the caller\'s appointment to a suitable available time.',

      informationToProvide: [
        'Appointments – first week in June:',

        'Monday: '
            '15:30 Marshall; '
            '16:00 Summer; '
            '16:15 Hill; '
            '16:30 Sims; '
            '16:45 Walsh; '
            '17:00 Zorro; '
            '17:15 Miller; '
            '17:30 Lambert; '
            '17:45 Debenham.',

        'Tuesday: '
            '15:30 Robson; '
            '15:45 Ewing; '
            '16:00 Dickson; '
            '16:15 Coolman; '
            '16:30 King; '
            '16:45 Snow; '
            '17:00 Lowry; '
            '17:15 Shriver; '
            '17:30 Clark.',

        'Wednesday: '
            '15:30 Sting; '
            '15:45 Kells; '
            '16:00 Carrington; '
            '16:15 Major; '
            '16:30 Riddle; '
            'Closed from 16:45 onward.',

        'Thursday: '
            '15:45 Gabriel; '
            '16:00 Jackson; '
            '16:45 Windsor; '
            '17:00 Clapton; '
            '17:15 Parker; '
            '17:30 Banks.',

        'Friday: '
            '16:45 Johnson.',
      ],

      informationToFind: [
        'Old appointment',
        'New appointment',
        'Reason: new glasses, check-up, or problems/pain',
      ],

      discussionQuestion:
          'How long does a check-up take?',
    ),
  ),
];