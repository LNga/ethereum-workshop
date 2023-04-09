// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

contract Lottery is
    VRFV2WrapperConsumerBase,
    ConfirmedOwner
    {
    uint public threshold; // Minimum tickets sold required to pick up a winner
    uint public totalTickets;
    address payable [] public players;
    mapping (address => uint) tickets; // Number of tickets per player
    mapping (address => bool) registeredPlayers;
    bool public closed = false;
    uint public ticketPrice;
    uint public maxAllowedTickets;
    uint public VRF_randomNumber;
    uint public requestId;

    event LotteryStatus(bool closedOrNot, uint leftTickets, uint prizeMoney);
    event WinnerLottery(bool closed, address player, uint earnings);
    event Received(address player, uint amount);

    modifier onlyOpen()  {
        require(!closed, 'Lottery has to be opened');
        _;
    }

    modifier enoughTickets(){        
        require(totalTickets>0, 'No tickets available in this lottery');
        _;
    }

    // VRF2 details
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    address linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address wrapperAddress = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;

    constructor(uint minimumTicketsRequired, uint initialNumberOfTickets)
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(linkAddress, wrapperAddress){
        require(initialNumberOfTickets>1, 'Minimum amount of tickets : 2');
        require(minimumTicketsRequired<initialNumberOfTickets, 'Tickets threshold can not exceed total number of tickets');

        threshold = minimumTicketsRequired;
        totalTickets = initialNumberOfTickets;
    }

    function setTicketsConditions(uint price, uint max) external onlyOwner  {
        require(max>0 && max<totalTickets, 'A player can buy at least one ticket but not all of the tickets');
        require(price>0, 'Price tickets can not be null');

        maxAllowedTickets = max;
        ticketPrice = price; 
    }

    function buyTickets(uint number) external payable onlyOpen enoughTickets { 
        require(tickets[msg.sender] + number <= maxAllowedTickets, 'Max allowed tickets per player reached');        require(number <= totalTickets, 'Number requested exceeds total tickets remaining in the lottery');
        uint totalPrice = number * ticketPrice; 
        require(msg.value == totalPrice, 'Insufficient funds');

        tickets[msg.sender] += number;
        totalTickets -= number;
        if (registeredPlayers[msg.sender]==false) players.push(payable(msg.sender));        
        registeredPlayers[msg.sender]=true;

        emit LotteryStatus(closed, totalTickets, address(this).balance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function pickWinner() public payable onlyOpen onlyOwner {
        require(totalTickets <= threshold, 'Threshold not reached');
        require(!closed, 'Lottery has to be opened');

        closed = true; // To avoid reentrancy
        randomRequest();
        uint randomIndex = VRF_randomNumber % players.length;
        address payable winner = players[randomIndex];
        uint prizeMoney =address(this).balance;
        winner.transfer(address(this).balance); 

        emit WinnerLottery(closed, winner, prizeMoney);
    }

    //VRFV2 function
    function randomRequest() private {
        requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
    }

    // VRFV2 fallback
    function fulfillRandomWords(uint256 _requestId,uint256[] memory _randomWords) internal override {
        requestId = _requestId;
        VRF_randomNumber = _randomWords[0];
    }

    /**
     * Allow withdraw of Link tokens from the contract (Link tokens are necessary for the contract to call VRFV2 contract)
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function getTicketsPerPlayer(address player) public view returns(uint){
        return tickets[player];
    }

    function getRegisteredPlayer(address player) public view returns(bool){
        return registeredPlayers[player];
    }

    function countPlayer() public view returns (uint){
        return players.length;
    }

}
