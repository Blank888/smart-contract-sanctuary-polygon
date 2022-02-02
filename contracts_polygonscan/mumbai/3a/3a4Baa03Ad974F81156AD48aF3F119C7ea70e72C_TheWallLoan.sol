/*
This file is part of the TheWall project.

The TheWall Contract is free software: you can redistribute it and/or
modify it under the terms of the GNU lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The TheWall Contract is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the TheWall Contract. If not, see <http://www.gnu.org/licenses/>.

@author Ilya Svirin <[email protected]>
*/
// SPDX-License-Identifier: GNU lesser General Public License

pragma solidity ^0.8.0;

import "./thewall.sol";


contract TheWallLoan is Context, IERC721Receiver
{
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using Address for address;
    using Address for address payable;

    event OfferCreated(address indexed lender, uint256 loanWei, uint256 refundWei, uint256 durationSeconds, int256 x1, int256 y1, int256 x2, int256 y2, uint256 indexed offerId);
    event OfferCanceled(uint256 indexed offerId);
    event AreaPickedUp(uint256 indexed offerId);
    event Borrowed(address indexed borrower, uint256 indexed offerId, uint256 indexed areaId);
    event Repaid(uint256 indexed offerId);

    TheWall     public _thewall;
    TheWallCore public _thewallcore;
    uint256     public _offersCounter;

    struct Offer
    {
        address lender;
        uint256 loanWei;
        uint256 refundWei;
        uint256 time;
        int256  x1;
        int256  y1;
        int256  x2;
        int256  y2;
        address borrower;
        uint256 areaId;
    }
    mapping (uint256 => Offer) public _offers;

    constructor(address payable thewall, address thewallcore)
    {
        _thewall = TheWall(thewall);
        _thewallcore = TheWallCore(thewallcore);
        _thewallcore.setNickname("The Wall Loan Protocol V2");
        _thewallcore.setAvatar('\x06\x01\x55\x12\x20\xc4\xea\xd2\x14\xd3\x14\x57\xbb\x91\x6e\xd9\x2a\xcd\xb6\x55\x5f\x2d\x53\x91\x12\x9b\x84\x72\xa6\x99\x27\x79\xeb\x61\x44\xf1\x6f');
    }

    function onERC721Received(address /*operator*/, address /*from*/, uint256 /*tokenId*/, bytes calldata /*data*/) public view override returns (bytes4)
    {
        require(_msgSender() == address(_thewall), "TheWallLoan: can receive TheWall Global tokens only");
        return this.onERC721Received.selector;
    }

    function createOffer(uint256 refundWei, uint256 durationSeconds, int256 x1, int256 y1, int256 x2, int256 y2) payable public returns(uint256)
    {
        require(refundWei >= msg.value, "TheWallLoan: Refund amount must be higher than loan amount");
        require(x1 <= x2 && y1 <= y2, "TheWallLoan: Invalid liquidity zone");
        require(durationSeconds <= 3650 days, "TheWallLoan: Invalid duration");
        return _createOffer(refundWei, durationSeconds, x1, y1, x2, y2, msg.value);
    }

    function createOffers(uint256 count, uint256 refundWei, uint256 durationSeconds, int256 x1, int256 y1, int256 x2, int256 y2) payable public
    {
        uint256 loanWei = msg.value / count;
        require(refundWei >= loanWei, "TheWallLoan: Refund amount must be higher than loan amount");
        require(x1 <= x2 && y1 <= y2, "TheWallLoan: Invalid liquidity zone");
        require(durationSeconds <= 3650 days, "TheWallLoan: Invalid duration");
        for(uint i = 0; i < count; ++i)
        {
            _createOffer(refundWei, durationSeconds, x1, y1, x2, y2, loanWei);
        }
    }

    function _createOffer(uint256 refundWei, uint256 durationSeconds, int256 x1, int256 y1, int256 x2, int256 y2, uint256 loanWei) internal returns(uint256 offerId)
    {
        Offer memory offer;
        offer.lender = _msgSender();
        offer.loanWei = loanWei;
        offer.refundWei = refundWei;
        offer.time = durationSeconds;
        offer.x1 = x1;
        offer.y1 = y1;
        offer.x2 = x2;
        offer.y2 = y2;
        
        _offersCounter = _offersCounter.add(1);
        offerId = _offersCounter;
        _offers[offerId] = offer;
        
        emit OfferCreated(offer.lender, offer.loanWei, offer.refundWei, durationSeconds, x1, y1, x2, y2, offerId);
    }
    
    function cancelOffer(uint256 offerId) public
    {
        Offer storage offer = _offers[offerId];
        require(offer.lender != address(0), "TheWallLoan: No offer found");
        require(offer.lender == _msgSender(), "TheWallLoan: Only offer's owner can cancel it");
        require(offer.borrower == address(0), "TheWallLoan: Can't cancel offer with borrower existed");
        address lender = offer.lender;
        uint256 loanWei = offer.loanWei;
        delete _offers[offerId];
        payable(lender).sendValue(loanWei);
        emit OfferCanceled(offerId);
    }

    function pickupArea(uint256 offerId) public returns(uint256 areaId)
    {
        Offer storage offer = _offers[offerId];
        require(offer.lender != address(0), "TheWallLoan: No offer found");
        require(offer.lender == _msgSender(), "TheWallLoan: Only offer's owner can pickup area");
        require(offer.areaId != 0, "TheWallLoan: No area to pickup");
        require(block.timestamp > offer.time, "TheWallLoan: Time of loan is not over yet");
        areaId = offer.areaId;
        address lender = offer.lender;
        delete _offers[offerId];
        _thewall.safeTransferFrom(address(this), lender, areaId);
        emit AreaPickedUp(offerId);
    }
    
    function borrow(uint256 offerId, int256 x, int256 y) public
    {
        Offer storage offer = _offers[offerId];
        require(offer.lender != address(0), "TheWallLoan: No offer found");
        require(offer.borrower == address(0), "TheWallLoan: Already have borrower for this offer");
        offer.borrower = _msgSender();
        offer.time = block.timestamp.add(offer.time);
        offer.areaId = _thewallcore._areaOnTheWall(x, y);
        require(offer.areaId != 0, "TheWallLoan: Area not found");

        require(x >= offer.x1 && x <= offer.x2 && y >= offer.y1 && y <= offer.y2,
                "TheWallLoan: Area is not in offer's liquidity zone");
        payable(offer.borrower).sendValue(offer.loanWei);
        _thewall.safeTransferFrom(_msgSender(), address(this), offer.areaId);

        /* We need to clear the listing flags for sale or rent for an area,
         * but we have no way of knowing if it is listed for sale or for rent.
         * Using try-catch solves the problem, but results in a scary message
         * in polygonscan. Therefore, we first put the area up for sale and
         * immediately cancel the operation.
         */
        //try _thewall.cancel(offer.areaId) {} catch {}
        _thewall.forSale(offer.areaId, 0);
        _thewall.cancel(offer.areaId);

        emit Borrowed(offer.borrower, offerId, offer.areaId);
    }
    
    function repay(uint256 offerId) payable public
    {
        Offer storage offer = _offers[offerId];
        require(offer.lender != address(0), "TheWallLoan: No offer found");
        require(offer.borrower == _msgSender(), "TheWallLoan: Only borrower can repay loan");
        require(block.timestamp <= offer.time, "TheWallLoan: Time of loan is already over");
        require(msg.value == offer.refundWei, "TheWallLoan: Invalid refund amount");
        address lender = offer.lender;
        uint256 areaId = offer.areaId;
        delete _offers[offerId];
        _thewall.safeTransferFrom(address(this), _msgSender(), areaId);
        payable(lender).sendValue(msg.value);
        emit Repaid(offerId);
   }
}