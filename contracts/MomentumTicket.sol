// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MomentumTicket is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 public eventCounter;

    struct Event {
        string name;
        uint256 date;
        string venue;
        uint256 totalTickets;
        uint256 ticketsSold;
        uint256 basePrice;
        bool cancelled;
    }

    struct Ticket {
        uint256 eventId;
        string seat;
        uint256 price;
        bool used;
    }

    mapping(uint256 => Event) public events;
    mapping(uint256 => Ticket) public tickets;

    event EventCreated(uint256 indexed eventId, string name, uint256 date);
    event TicketMinted(uint256 indexed tokenId, uint256 indexed eventId, address owner);
    event TicketUsed(uint256 indexed tokenId);
    event EventCancelled(uint256 indexed eventId);

    constructor() ERC721("MomentumTicket", "MTK") {}

    function createEvent(string memory _name, uint256 _date, string memory _venue, uint256 _totalTickets, uint256 _basePrice) public onlyOwner {
        eventCounter++;
        events[eventCounter] = Event(_name, _date, _venue, _totalTickets, 0, _basePrice, false);
        emit EventCreated(eventCounter, _name, _date);
    }

    function mintTicket(uint256 _eventId, string memory _seat) public payable {
        require(!events[_eventId].cancelled, "Event has been cancelled");
        require(events[_eventId].ticketsSold < events[_eventId].totalTickets, "Event is sold out");
        
        uint256 ticketPrice = calculateTicketPrice(_eventId);
        require(msg.value >= ticketPrice, "Insufficient payment");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);

        tickets[newTokenId] = Ticket(_eventId, _seat, ticketPrice, false);
        events[_eventId].ticketsSold++;

        emit TicketMinted(newTokenId, _eventId, msg.sender);

        if (msg.value > ticketPrice) {
            payable(msg.sender).transfer(msg.value - ticketPrice);
        }
    }

    function calculateTicketPrice(uint256 _eventId) public view returns (uint256) {
        Event memory event = events[_eventId];
        uint256 soldPercentage = (event.ticketsSold * 100) / event.totalTickets;
        
        if (soldPercentage < 50) {
            return event.basePrice;
        } else if (soldPercentage < 75) {
            return event.basePrice * 3 / 2;  // 50% increase
        } else {
            return event.basePrice * 2;  // 100% increase
        }
    }

    function useTicket(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Not the ticket owner");
        require(!tickets[_tokenId].used, "Ticket already used");
        require(!events[tickets[_tokenId].eventId].cancelled, "Event has been cancelled");

        tickets[_tokenId].used = true;
        emit TicketUsed(_tokenId);
    }

    function transferTicket(address _to, uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Not the ticket owner");
        require(!tickets[_tokenId].used, "Ticket already used");
        require(!events[tickets[_tokenId].eventId].cancelled, "Event has been cancelled");

        _transfer(msg.sender, _to, _tokenId);
    }

    function cancelEvent(uint256 _eventId) public onlyOwner {
        require(!events[_eventId].cancelled, "Event already cancelled");
        events[_eventId].cancelled = true;
        emit EventCancelled(_eventId);
    }

    function refundTicket(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Not the ticket owner");
        require(events[tickets[_tokenId].eventId].cancelled, "Event not cancelled");

        uint256 refundAmount = tickets[_tokenId].price;
        _burn(_tokenId);
        delete tickets[_tokenId];
        payable(msg.sender).transfer(refundAmount);
    }

    function getTicketDetails(uint256 _tokenId) public view returns (uint256, string memory, uint256, bool) {
        Ticket memory ticket = tickets[_tokenId];
        return (ticket.eventId, ticket.seat, ticket.price, ticket.used);
    }

    function getEventDetails(uint256 _eventId) public view returns (string memory, uint256, string memory, uint256, uint256, bool) {
        Event memory event = events[_eventId];
        return (event.name, event.date, event.venue, event.totalTickets, event.ticketsSold, event.cancelled);
    }
}
