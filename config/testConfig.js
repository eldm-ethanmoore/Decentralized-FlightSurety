
var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require('bignumber.js');
var TruffleAssert = require('truffle-assertions');

var Config = async function(accounts) {
    
    // These test addresses are useful when you need to add
    // multiple users in test scripts
    let testAddresses = [
        "0x69e1CB5cFcA8A311586e3406ed0301C06fb839a2",
        "0xF014343BDFFbED8660A9d8721deC985126f189F3",
        "0x0E79EDbD6A727CfeE09A2b1d0A59F7752d5bf7C9",
        "0x9bC1169Ca09555bf2721A5C9eC6D69c8073bfeB4",
        "0xa23eAEf02F9E0338EEcDa8Fdd0A73aDD781b2A86",
        "0x6b85cc8f612d5457d49775439335f83e12b8cfde",
        "0xcbd22ff1ded1423fbc24a7af2148745878800024",
        "0xc257274276a4e539741ca11b590b9447b26a8051",
        "0x2f2899d6d35b1a48a4fbdc93a37a72f264a9fca7"
    ];


    let owner = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57";
    let firstAirline = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
    let flightSuretyData = await FlightSuretyData.new();
    let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address);

    let STATUS_CODE = {
        UNKNOWN: '0',
        ON_TIME: '10',
        LATE_AIRLINE: '20',
        LATE_WEATHER: '30',
        LATE_TECHNICAL: '40',
        LATE_OTHER: '50'
    }


    let flights = [
    {
        airlineAddr: firstAirline,
        name: 'HR305',
        departure: Math.floor(1000000 / 1000),
        ticketNumbers: ['102', '103', '124', '152', '161', '172', '173', '174', '201', '205'],
        extraTicketNumbers: ['101', '104', '131', '132', '133', '134', '141', '144', '202'],
        statusCode: STATUS_CODE.LATE_AIRLINE,
        chosenIndex: 0,
    }
    ]

    let tickets = [
    {
        flight: flights[0],
        number: flights[0].ticketNumbers[0],
        insuranceValue: web3.utils.toWei('1', "ether"),
    }
    ];


    return {
        owner: owner,
        firstAirline: firstAirline,
        STATUS_CODE: STATUS_CODE,
        flights: flights,
        tickets: tickets,
        weiMultiple: (new BigNumber(10)).pow(18),
        testAddresses: testAddresses,
        flightSuretyData: flightSuretyData,
        flightSuretyApp: flightSuretyApp
    }
}

module.exports = {
    Config: Config
};