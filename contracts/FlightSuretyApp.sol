pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";
/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    uint8 private rateOfCredit = 150;

    address private contractOwner;          // Account used to deploy contract

    struct Airline{
        bool exists;
        bool registered;
        bool funded;
        bytes32[] flightKeys;
        Votes votes;
        uint numberOfInsurance;
    }

    struct Votes{
        uint votesCounter;
        mapping(address => bool) voters;
    }

    struct Flight {
        bool isRegistered;
        string name;
        uint256 departure;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }

    mapping(bytes32 => Flight) private flights;
    bool private operational = true;
    FlightSuretyData dataContract;

    /********************************************************************************************/
    /*                                       EVENTS                                             */
    /********************************************************************************************/

    event AirlineRegistered(address airlineAddr);
    event AirlineAdded(address airlineAddr);
    event FlightRegistered(bytes32 flightKey);
    event FlightTicketsAdded(uint256 ticketNumbers, bytes32 flightKey);
    event InsuranceBought(bytes32 insuranceKey);
    event CreditDrawed(uint256 vaule);
    event FlightProcessed(address airline, string flight, uint256 timestamp, uint8 statusCode, bytes32 flightKey, uint8 rateOfCredit);
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(operational, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAirlineFunded(address airlineAddr)
    {
        require(dataContract.isFunded(airlineAddr), "not funded");
        _;
    }
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address flightSuretyDataAddr
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(flightSuretyDataAddr);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view
                            returns(bool) 
    {
        return operational;  // Modify to call data contract's status
    }

    function setOperatingStatus
                                (
                                    bool _operational
                                )
                                public
                                requireContractOwner
    {
        operational = _operational;
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (   
                                address airlineAddr
                            )
                            public
                            requireIsOperational
                            requireAirlineFunded(msg.sender)
                            returns(bool success, uint256 votes)
    {
        bool consensus = isConsensusNeeded();
        if(!consensus)
        {
            dataContract.registerAirlineData(airlineAddr, true);
            emit AirlineRegistered(airlineAddr);
        } 
        if(consensus)
        {

            dataContract.isConsensusReached(airlineAddr);
            emit AirlineAdded(airlineAddr);
        }

         return (success, 0);
    }

    function isConsensusNeeded(

                                )
                            public
                            requireIsOperational
                            returns(bool)
    {
        uint256 numAirline = dataContract.getAirlineCounter();
        if(numAirline >= 5)
        {
            return true;
        } else {
            return false;
        }
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    uint256 departure,
                                    uint256[] ticketNumbers,
                                    string flightName
                                )
                                public
                                requireIsOperational
                                requireAirlineFunded(msg.sender)
                                returns(bytes32)

    {
        bytes32 flightKey = dataContract.getFlightKey(msg.sender, flightName, departure);
        require(!flights[flightKey].isRegistered, "Flight already registered");

        flights[flightKey] = Flight ({
            isRegistered: true,
            name: flightName,
            departure: departure,
            statusCode: 0,
            updatedTimestamp: now,
            airline: msg.sender
        });

        dataContract.addFlightKeyToAirline(msg.sender, flightKey);
        for(uint256 i = 0;i < ticketNumbers.length; i++)
        {
           dataContract.createFlightInsurance(msg.sender, flightKey, ticketNumbers[i]); 
           emit FlightRegistered(flightKey);
           emit FlightTicketsAdded(ticketNumbers[i], flightKey);
        }
        return flightKey;
    }
    //event insuranceBought(bytes32 flightKey, bytes32 insuranceKey, string flightName, address airlineAddr);
    function buyInsurance
                        (
                            address airlineAddr,
                            string flightName,
                            uint256 departure,
                            uint256 ticketNumber
                        )
                        public
                        payable
                        requireIsOperational

    {
        //emit insuranceBought(flightKey, insuranceKey, flightName, airlineAddr);
        require(msg.value > 0, "can accept more than 0");
        require(msg.value <= 1 ether, "Insurance can accept less than 1 ether");


        bytes32 flightKey = getFlightKey(airlineAddr, flightName, departure);
        bytes32 insuranceKey = getInsuranceKey(flightKey, ticketNumber);

        dataContract.buyInsurance.value(msg.value)(msg.sender, insuranceKey);

        emit InsuranceBought(insuranceKey);
    }

    function getInsurance
                        (
                            address airlineAddr,
                            string flightName,
                            uint256 departureTime,
                            uint256 _ticketNumber
                        )
                        public
                        returns(
                            address buyer,
                            uint256 value
                        )
    {
        bytes32 flightKey = dataContract.getFlightKey(airlineAddr, flightName, departureTime);
        bytes32 insuranceKey = getInsuranceKey(flightKey, _ticketNumber);

        return dataContract.fetchInsuranceData(insuranceKey);
    }

    function getInsuranceKey
                            (
                                bytes32 flightKey,
                                uint256 ticketNumber
                            )
                            public
                            returns(bytes32)
    {
        return keccak256(abi.encodePacked(flightKey, ticketNumber));
    }


    function getInsuranceKeysOfPassenger
                                        (
                                            address passengerAddr
                                        )
                                        public
                                        view
                                        returns(bytes32[] memory)
    {
        return dataContract.fetchPassengerInsurances(passengerAddr);
    }


   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                public
                                requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        flights[flightKey].statusCode = statusCode;

        if(statusCode == STATUS_CODE_LATE_AIRLINE)
        {
            emit FlightProcessed(airline, flight, timestamp, statusCode, flightKey, rateOfCredit);
            dataContract.creditInsurees(flightKey, rateOfCredit);
        }
    }

    function getPassengerCreditAmount
                                    (
                                    )
                                    public  
                                    requireIsOperational
                                    returns(uint256)
    {

        uint256 credit = dataContract.fetchPassengerInsuranceValue(getInsuranceKeysOfPassenger(msg.sender)[0]);
        return credit;
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        requireIsOperational
                        public
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 

    function payInsurance
                        (
                            address airlineAddr,
                            string name,
                            uint256 departure,
                            uint256 ticketNumber
                        )
                        public
                        requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airlineAddr, name, departure);
        bytes32 insuranceKey = getInsuranceKey(flightKey, ticketNumber);

        (address insuree, uint256 value) = dataContract.fetchInsuranceData(insuranceKey);
        //require(insuree == msg.sender, "dont own this insurance");
        dataContract.payInsuree(insuranceKey);
        emit CreditDrawed(value);
    }

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
