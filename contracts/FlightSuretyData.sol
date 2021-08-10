pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    bool private isActiveVoting = false;

    mapping (address => bool) private authorizedCallers;

    uint256 private airlineCounter = 0;
    uint256 private registeredAirlineCounter = 0;
    uint256 private fundedAirlineCounter = 0;
    uint256 private totalVotes = 0;

    mapping(uint256 => address) voterAddresses;
    mapping(address => bool) voterStatus;

    struct Airline{
        bool exists;
        bool registered;
        bool funded;
        bytes32[] flightKeys;
        uint256 votesCounter;
        uint numberOfInsurance;
    }

    struct Flight {
        bool isRegistered;
        string name;
        uint256 departure;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }

    struct Insurance {
        address buyer;
        address airlineAddr;
        uint256 value;
        uint256 ticketNumber;
    }

    mapping (address => Airline) private airlines;
    mapping (address => Flight) private flights;
    mapping(bytes32 => Insurance) private insurances;
    mapping(bytes32 => bytes32[]) private flightInsuranceKeys;
    mapping(address => bytes32[]) private passengerInsuranceKeys;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AuthorizedCaller(address contractAddr);
    event AirlineExists(address airlineAddr, bool exist);
    event AirlineRegistered(address airlineAddr, bool exist, bool registered);
    event AirlineFunded(address airlineAddr, bool exist, bool registered, bool funded);
    event AirlineVote(address airlineAddr, address voterAddr, uint256 startVote, uint256 totalVotes);
    event InsurancePaid(uint256 amount, address to);
    event insuranceValueEvent(uint256 insuranceValue);
    event FlightInsuranceBuilt(bytes32 ik);
    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        address firstAirline = 0xf17f52151EbEF6C7334FAD080c5704D77216b732;
        registerAirlineData(firstAirline, true);
    }

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

    modifier requireAirlineRegistered(address airlineAddr)
    {
        require(airlines[airlineAddr].registered, "Not registered");
        _;
    }

    modifier requireAirlineFunded(address airlineAddr)
    {
        require(airlines[airlineAddr].funded, "Not funded");
        _;
    }

    modifier requireNotActiveVoting()
    {
        require(!isActiveVoting, "Voting is active");
        _;
    }

    modifier requireActiveVoting()
    {
        require(isActiveVoting, "Voting is not active");
        _;
    }
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function authorizeCaller
                            (
                                address contractAddr
                            )
                            public
                            requireContractOwner
                            requireIsOperational
    {
        authorizedCallers[contractAddr] = true;
        emit AuthorizedCaller(contractAddr);
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirlineData
                            (   
                                address airlineAddr,
                                bool isRegistered
                            )
                            requireIsOperational
                            public
                            view
    {

        if(isRegistered)
        {
            airlines[airlineAddr] = Airline({
                exists: true,
                registered: true,
                funded: false,
                flightKeys: new bytes32[](0),
                votesCounter: 0,
                numberOfInsurance: 0
            });
            airlineCounter = airlineCounter.add(1);
            registeredAirlineCounter = registeredAirlineCounter.add(1);
            emit AirlineRegistered(airlineAddr, airlines[airlineAddr].exists, airlines[airlineAddr].registered);
        }
    }

    function getAirlineCounter
                            (
                            )
                            public 
                            view
                            returns(uint256)
    {
        return registeredAirlineCounter;
    }

    function isAirline
                        (
                            address airlineAddr
                        )
                        public
                        view
                        returns(bool)
    {
        if(airlines[airlineAddr].exists)
        {
            bool exists = airlines[airlineAddr].registered;
            return exists ;
        } else {
            return false;
        }
        return false;
    }

    function isAirlineRegistered
                        (
                            address airlineAddr
                        )
                        public
                        view
                        returns(bool)
    {
        if(airlines[airlineAddr].registered)
        {
            bool isRegistered = airlines[airlineAddr].registered;
            return isRegistered;
        } else {
            return false;
        }
        return false;
    }

    function airlineVote
                        (
                            address voterAddr                            
                        )
                        public
                        requireIsOperational
                        returns(bool)
    {
        address airlineAddr = msg.sender;
        require(voterStatus[airlineAddr] == false);
        voterStatus[airlineAddr] = true;
        require(voterStatus[airlineAddr] == true);
        uint256 startVote = getNumberOfVotesCounter();
        totalVotes = totalVotes.add(1);
        require(totalVotes == startVote.add(1), 'not incremented');
        voterAddresses[totalVotes] = airlineAddr;
        emit AirlineVote(airlineAddr, voterAddr, startVote, totalVotes);
        return true;
    }

    function isConsensusReached(address votedAddr)
    public
    requireIsOperational
    returns(bool)
    {
        uint256 numVotes = getNumberOfVotesCounter();
        uint256 threshold = getAirlineCounter().div(2);
        if(numVotes >= threshold) {
            //isActiveVoting = false;
            airlines[votedAddr].registered = true;
            totalVotes = 0;
            return true;
        }
        return false;
    }

    function getVotingStatus()
    public
    view
    requireIsOperational
    returns(bool)
    {
        return isActiveVoting;
    }

    function getNumberOfVotesCounter
                            (
                            )
                            public
                            view
                            requireIsOperational
                            returns(uint256)
    {
        return totalVotes;
    }

    function isFunded
                    (
                        address airlineAddr
                    )
                    public
                    view 
                    returns(bool)
    {
        return airlines[airlineAddr].exists;
    }

    function addFlightKeyToAirline
                                (
                                    address airlineAddr,
                                    bytes32 flightKey                               
                                )
                                public
                                requireIsOperational
    {
        airlines[airlineAddr].flightKeys.push(flightKey);
    }

    function createFlightInsurance
                                (
                                    address airlineAddr,
                                    bytes32 flightKey,
                                    uint256 ticketNumber
                                )
                                public
    {
        bytes32 insuranceKey = getInsuranceKey(flightKey, ticketNumber);

        insurances[insuranceKey] = Insurance({
            buyer: address(0),
            airlineAddr: airlineAddr,
            value: 0,
            ticketNumber: ticketNumber
        });

        flightInsuranceKeys[flightKey].push(insuranceKey);
        emit FlightInsuranceBuilt(insuranceKey);
    }

    function buyInsurance
                        (
                            address buyer,
                            bytes32 insuranceKey
                        )
                        public
                        payable
    {
        insurances[insuranceKey].buyer = buyer;
        insurances[insuranceKey].value = msg.value;
        passengerInsuranceKeys[buyer].push(insuranceKey);
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


    function fetchInsuranceData
                                (
                                    bytes32 insuranceKey
                                )
                                public
                                requireIsOperational
                                returns(address buyer, uint256 value)
    {
       Insurance storage insurance = insurances[insuranceKey];
       return(insurance.buyer, insurance.value); 
    }

    function setPassengerInsuranceValue(
                                           bytes32 insuranceKey,
                                           uint256 value
                                        )
                                        public
                                        requireIsOperational
                                        returns(uint256)
                                        {
                                            Insurance storage insurance = insurances[insuranceKey];
                                            insurance.value = value;
                                            return insurance.value;
                                        }

    function fetchPassengerInsuranceValue(
                                           bytes32 insuranceKey 
                                        )
                                        public
                                        requireIsOperational
                                        returns(uint256)
    {
        Insurance storage insurance = insurances[insuranceKey];
        return insurance.value;
    }

    function fetchPassengerInsurances
                                    (
                                        address passengerAddr
                                    )
                                    public
                                    requireIsOperational
                                    returns(bytes32[])
    {
        return passengerInsuranceKeys[passengerAddr];
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    bytes32 flightKey,
                                    uint8 rateOfCredit
                                )
                                public
                                requireIsOperational
    {
        //bytes32 fk = 0x3e817e86b18de8fad35cc0d8e5ea3903e7ab0f119a770bbf6dc62628920d5a06;
        //bytes32 ik = 0x1b80017544d64f172cd3847a8fd65b2ba9e3225f2a70773a85a1e7893cec15db;
        bytes32[] storage _insuranceKeys = flightInsuranceKeys[flightKey];
        uint256 value;
        emit insuranceValueEvent(_insuranceKeys.length);
        for(uint i=0; i < _insuranceKeys.length; i++)
        {
            value = setPassengerInsuranceValue(_insuranceKeys[0], (fetchPassengerInsuranceValue(_insuranceKeys[0]).mul(rateOfCredit).div(100)));
        }
    }
    
    function payInsuree
                        (
                            bytes32 insuranceKey
                        )
                        public
                        payable
    {
        Insurance memory _insurance = insurances[insuranceKey];

        //require(address(this).balance > _insurance.value, "try again later");

        uint256 _value = _insurance.value;
        _insurance.value = 0;
        address insuree = address(uint160(_insurance.buyer));
        insuree.transfer(_value);
        emit InsurancePaid(_value, insuree);
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                                address airlineAddr
                            )
                            public
                            payable
                            requireIsOperational
    {
        require(msg.value >= 10 ether);
        airlines[airlineAddr].funded = true;
        fundedAirlineCounter = fundedAirlineCounter.add(1);
        emit AirlineFunded(airlineAddr, airlines[airlineAddr].exists, airlines[airlineAddr].registered, airlines[airlineAddr].funded);
        
    }

    function getFlightKey
                        (
                            address airlineAddr,
                            string memory flight,
                            uint256 timestamp
                        )
                        public
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airlineAddr, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund(msg.sender);
    }


}

