
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var TruffleAssert = require('truffle-assertions');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) First Airline is registered when contract is deployed', async () => {

    // ARRANGE
    let firstAirline = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
    let result = await config.flightSuretyData.isAirlineRegistered(firstAirline);

    // ACT
    try {
        await config.flightSuretyData.fund.call(firstAirline, {from: firstAirline, value: web3.utils.toWei('10','ether')});
    }
    catch(e) {

    }

    // ASSERT
    assert.equal(result, true, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let secondAirline = "0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef";

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(secondAirline, {from: secondAirline});
    }
    catch(e) {

    }
    let isRegistered = await config.flightSuretyData.isAirline.call(secondAirline); 

    // ASSERT
    assert.equal(isRegistered, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) Airline can be registered but doesnt participate in contract until funding is submitted', async () => {

    // ASSERT
    let firstAirline = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
    let secondAirline = "0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef";
    let isVoted = false;
    let isRegistered = false; 

    // ACT
    try{
        await config.flightSuretyApp.registerAirline(secondAirline, {from: firstAirline});
        isRegistered= await config.flightSuretyData.isAirlineRegistered(secondAirline, {from: secondAirline});
    } catch(e) {
      isVoted = await config.flightSuretyData.airlineVote(secondAirline, {from: secondAirline});
    }



    // ASSERT

    assert.equal(isRegistered, true, "Airline two should be registered");
    assert.equal(isVoted, false, "Airline two should not vote");
  });

  it('(airline) Registering new Airlines until the voting mechanism goes into effect', async () => {

    // ARRANGE
    let firstAirline = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
    let secondAirline = "0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef";
    let thirdAirline = "0x821aEa9a577a9b44299B9c15c88cf3087F3b5544";
    let fourthAirline = "0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2";

    // ACT
    try{


        await config.flightSuretyApp.registerAirline(secondAirline, {from: firstAirline});
        await config.flightSuretyData.fund.call(secondAirline, {from: secondAirline, value: web3.utils.toWei('10','ether')});


        await config.flightSuretyApp.registerAirline(thirdAirline, {from: firstAirline});
        await config.flightSuretyData.fund.call(thirdAirline, {from: thirdAirline, value: web3.utils.toWei('10','ether')});

        await config.flightSuretyApp.registerAirline(fourthAirline, {from: thirdAirline});
        await config.flightSuretyData.fund.call(fourthAirline, {from: fourthAirline, value: web3.utils.toWei('10','ether')});

    } catch(e) {

    }


    let isAirlineTwoRegistered = await config.flightSuretyData.isAirlineRegistered.call(secondAirline); 
    let isAirlineThreeRegistered = await config.flightSuretyData.isAirlineRegistered.call(thirdAirline); 
    let isAirlineFourRegistered = await config.flightSuretyData.isAirlineRegistered.call(fourthAirline); 

    // ASSERT

    assert.equal(isAirlineTwoRegistered, true, "Airline two is not registered");
    assert.equal(isAirlineThreeRegistered, true, "Airline three is not registered");
    assert.equal(isAirlineFourRegistered, true, "Airline four is not registered");

  });

  it('(airline) Registering the 5th Airline without the correct consensus fails registration', async () => {

    //ARRANGE
    let fourthAirline = "0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2";
    let fifthAirline = "0x2932b7A2355D6fecc4b5c0B6BD44cC31df247a2e";


    //ACT
    try {

        await config.flightSuretyApp.registerAirline(fifthAirline, {from: fourthAirline});
        await config.flightSuretyData.fund.call(fifthAirline, {from: fifthAirline, value: web3.utils.toWei('10','ether')});

    } catch(e) {

    }

    let isAirlineFifthRegistered = await config.flightSuretyData.isAirlineRegistered.call(fifthAirline);

    //ASSERT
    assert.equal(isAirlineFifthRegistered, false);


    
  });



  it('(airline) Registering 5th Airline and subsequent requires consensus of %50 of registered airlines', async () => {

    //ARRANGE
    let firstAirline = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
    let secondAirline = "0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef";
    let thirdAirline = "0x821aEa9a577a9b44299B9c15c88cf3087F3b5544";
    let fourthAirline = "0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2";
    let fifthAirline = "0x2932b7A2355D6fecc4b5c0B6BD44cC31df247a2e";

    //ACT
    try {

        await config.flightSuretyData.airlineVote(fifthAirline, {from: firstAirline});
        await config.flightSuretyData.airlineVote(fifthAirline, {from: thirdAirline});
        await config.flightSuretyData.airlineVote(fifthAirline, {from: fourthAirline});
        await config.flightSuretyData.isConsensusReached(fifthAirline, {from: fifthAirline});
        await config.flightSuretyData.fund(fifthAirline, {from: firstAirline, value: web3.utils.toWei('10','ether')});
        
    } catch(e) {
      

    }

    let isAirlineFifthRegistered = await config.flightSuretyData.isAirlineRegistered(fifthAirline);

    //ASSERT
    assert.equal(isAirlineFifthRegistered, true);

  });

  it('(flight) Register a flight', async () => {

    //ARRANGE
    let firstAirline = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
    let flightKeyFromData;
    let flightKey = "0x3e817e86b18de8fad35cc0d8e5ea3903e7ab0f119a770bbf6dc62628920d5a06";
    //ACT
    try {


      flightKeyFromData = await config.flightSuretyApp.registerFlight.call(config.tickets[0].flight.departure, config.tickets[0].flight.ticketNumbers, config.tickets[0].flight.name, {from: firstAirline});

    } catch(e) {

    }


    //ASSERT
    assert.equal(flightKeyFromData, flightKey, "Flight keys do not match");

  });

  it('(flight) Buy Insurance', async () => {

    //ARRANGE
    let sixthPassenger = "0x2191eF87E392377ec08E7c08Eb105Ef5448eCED5";

    //ACT
    try {
      await config.flightSuretyApp.buyInsurance(
                                                      config.tickets[0].flight.airlineAddr,
                                                      config.tickets[0].flight.name,
                                                      config.tickets[0].flight.departure,
                                                      config.tickets[0].number,
                                                      {from: sixthPassenger, value: config.tickets[0].insuranceValue});
                                                    


    } catch(e) {

    }


      let insurance = await config.flightSuretyApp.getInsurance.call(
                                                    config.tickets[0].flight.airlineAddr,
                                                    config.tickets[0].flight.name,
                                                    config.tickets[0].flight.departure,
                                                    config.tickets[0].number,
                                                    {from: sixthPassenger});


    //ASSERT
    assert.equal(insurance.buyer, sixthPassenger, "Buyer of insurance does not match");

  });

  it('(flight) Insurance Keys are added to passenger array', async () => {

    //ARRANGE
    let sixthPassenger = "0x2191eF87E392377ec08E7c08Eb105Ef5448eCED5";
    let contractOwner = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57";
    let passengerInsuranceKeys;
    //ACT
    try {
      passengerInsuranceKeys = await config.flightSuretyApp.getInsuranceKeysOfPassenger(sixthPassenger, {from: sixthPassenger});
    } catch(e) {

    }




    //ASSERT
    assert.equal(passengerInsuranceKeys.length, 1);

  });

  it('(flight) can request flight status', async () => {

    //ARRANGE
    let sixthPassenger = "0x2191eF87E392377ec08E7c08Eb105Ef5448eCED5";
    let contractOwner = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57";
    //ACT
    try {

    } catch(e) {

    }

      await config.flightSuretyApp.fetchFlightStatus(config.tickets[0].flight.airlineAddr,
                                                          config.tickets[0].flight.name,
                                                          config.tickets[0].flight.departure,
                                                           {from: sixthPassenger});


    //ASSERT

  });

  it('(flight) Credited passenger can withdraw ether', async () => {
    //ARRANGE
    let sixthPassenger = "0x2191eF87E392377ec08E7c08Eb105Ef5448eCED5";
    let passengerBalBefore = new BigNumber(web3.utils.fromWei(await web3.eth.getBalance(sixthPassenger), 'ether'));
    let rateOfCredit = web3.utils.fromWei(String(config.tickets[0].insuranceValue*1.5));
    //ACT
    try {
    } catch(e) {
    }
    //ASSERT

      await config.flightSuretyApp.processFlightStatus(
                                    config.tickets[0].flight.airlineAddr,
                                    config.tickets[0].flight.name,
                                    config.tickets[0].flight.departure,
                                    20
                                                      );  

      await config.flightSuretyApp.payInsurance(
          config.tickets[0].flight.airlineAddr,
          config.tickets[0].flight.name,
          config.tickets[0].flight.departure,
          config.tickets[0].number,
          {from: sixthPassenger }
          );
        

      let passengerBalAfter = new BigNumber(web3.utils.fromWei(await web3.eth.getBalance(sixthPassenger)));
      let bal = passengerBalAfter - passengerBalBefore;
      let gas = 1.5-bal;
      //console.log(passengerBalanceAfter);
      //console.log(passengerBalanceBefore);
      //console.log(bal);
      //console.log(gas);
      assert.equal(rateOfCredit, bal+gas);
      
  });

 });
  /*
(0) 0x627306090abaB3A6e1400e9345bC60c78a8BEf57 (100 ETH)
(1) 0xf17f52151EbEF6C7334FAD080c5704D77216b732 (100 ETH)
(2) 0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef (100 ETH)
(3) 0x821aEa9a577a9b44299B9c15c88cf3087F3b5544 (100 ETH)
(4) 0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2 (100 ETH)
(5) 0x2932b7A2355D6fecc4b5c0B6BD44cC31df247a2e (100 ETH)
(6) 0x2191eF87E392377ec08E7c08Eb105Ef5448eCED5 (100 ETH)
(7) 0x0F4F2Ac550A1b4e2280d04c21cEa7EBD822934b5 (100 ETH)
(8) 0x6330A553Fc93768F612722BB8c2eC78aC90B3bbc (100 ETH)
(9) 0x5AEDA56215b167893e80B4fE645BA6d5Bab767DE (100 ETH)
  */
