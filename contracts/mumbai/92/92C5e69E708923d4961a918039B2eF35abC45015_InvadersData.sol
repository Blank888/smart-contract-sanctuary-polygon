// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./StarShips.sol";
import "./Planets.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FenwickTree.sol";
import "./VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./ABDK.sol";

interface IInvadersForceField {
  function planetIdToForceField(uint256 planetId) external returns (uint256);
}

/// @author nftboi and tr666
/// @title Invaders! P2E Game
contract InvadersData is
  ReentrancyGuard,
  IERC721Receiver,
  VRFConsumerBase,
  Ownable,
  Pausable
{
  using FenwickTree for FenwickTree.Bit;
  using ABDKMath64x64 for int128;

  FenwickTree.Bit miningPowerRewardPerEpoch;
  StarShips public SHIPS;
  PixelglyphPlanets public PLANETS;
  IInvadersForceField public FF;

  ERC20 public EL69;
  uint256 public START_TIME;
  uint256 public PRICE_PER_DISTANCE;
  uint256 public lastSavedEpoch;
  uint256 public totalMiningPower;
  uint256 public BASE_STEAL_PRICE;

  struct Ship {
    bool exists;
    bool mining;
    bool piratePending;
    uint256 travelingUntil;
    uint256 disabledUntil;
    // planet ID from where the ship is coming from
    uint256 travelingFrom;
    uint256 startEpoch;
    uint256 endEpoch;
    uint256 planetId;
    uint256 shipId;
    // index in allShips array
    uint256 idx;
    // index in shipsOnPlanet array
    uint256 planetIdx;
    address owner;
  }

  struct Planet {
    bool exists;
    uint256 planetId;
    uint256 idx;
    address owner;
    uint256 miningShipId;
    bool pendingClaim;
  }

  modifier onlyGameContract() {
    require(isGameContract[msg.sender] == true, "Must be game contract");
    _;
  }

  mapping(address => bool) public isGameContract;
  // array of all ship IDs
  uint256[] public _allShips;
  // mapping of ship ID to Ship struct
  mapping(uint256 => Ship) public ships;
  // mapping of address to index to ship ID
  mapping(address => uint256[]) public ownedShips;
  // mapping of ship ID to index in ownedShips array
  mapping(uint256 => uint256) public ownedShipIndex;
  uint256[] public _allPlanets;

  mapping(uint256 => Planet) public planets;
  mapping(address => uint256[]) public ownedPlanets;
  mapping(uint256 => uint256) public ownedPlanetIndex;
  mapping(uint256 => uint256[]) public shipsOnPlanet;

  bytes32 keyHash;
  uint256 fee;

  constructor(
    address shipAddress,
    address planetAddress,
    address el69,
    address ff,
    uint256 pricePerDistance,
    uint256 baseStealPrice,
    address _vrfCoordinator,
    address _linkToken,
    uint256 _vrfFee,
    bytes32 _keyHash
  ) VRFConsumerBase(_vrfCoordinator, _linkToken) Pausable() {
    miningPowerRewardPerEpoch.arr.push(0);
    SHIPS = StarShips(shipAddress);
    PLANETS = PixelglyphPlanets(planetAddress);
    EL69 = ERC20(el69);
    START_TIME = block.timestamp;
    PRICE_PER_DISTANCE = pricePerDistance;
    keyHash = _keyHash;
    fee = _vrfFee;
    BASE_STEAL_PRICE = baseStealPrice;
    FF = IInvadersForceField(ff);
  }

  function updateVrfFee(uint256 vrfFee) public onlyOwner {
    fee = vrfFee;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function updatePricePerDistance(uint256 val) public onlyOwner {
    PRICE_PER_DISTANCE = val;
  }

  function updateGameContract(address gameContract, bool val) public onlyOwner {
    isGameContract[gameContract] = val;
  }

  function getTotalShipsOnPlanet(uint256 planetId)
    public
    view
    returns (uint256)
  {
    return shipsOnPlanet[planetId].length;
  }

  function getShipOnPlanetByIndex(uint256 planetId, uint256 idx)
    public
    view
    returns (uint256)
  {
    return shipsOnPlanet[planetId][idx];
  }

  /** @dev Function to get a planet ID by index. Can be used for iteration on front end */
  function getPlanetByIndex(uint256 idx) public view returns (uint256) {
    return _allPlanets[idx];
  }

  /** @dev Get the total number of planets enabled for gameplay. Can be used in conjunction with getPlanetByIndex for iteration */
  function getTotalPlanets() public view returns (uint256) {
    return _allPlanets.length;
  }

  /** @dev Function to get a ship ID by index. Can be used for iteration on front end */
  function getShipByIndex(uint256 idx) public view returns (uint256) {
    return _allShips[idx];
  }

  /** @dev Get the total number of ships enabled for gameplay. Can be used in conjunction with getShipByIndex for iteration */
  function getTotalShips() public view returns (uint256) {
    return _allShips.length;
  }

  /** @dev Function to get a planet ID by index. Can be used for iteration on front end */
  function getOwnedPlanetByIndex(address owner, uint256 idx)
    public
    view
    returns (uint256)
  {
    return ownedPlanets[owner][idx];
  }

  /** @dev Get the total number of planets enabled for gameplay. Can be used in conjunction with getPlanetByIndex for iteration */
  function getTotalOwnedPlanets(address owner) public view returns (uint256) {
    return ownedPlanets[owner].length;
  }

  /** @dev Function to get a ship ID by index. Can be used for iteration on front end */
  function getOwnedShipByIndex(address owner, uint256 idx)
    public
    view
    returns (uint256)
  {
    return ownedShips[owner][idx];
  }

  /** @dev Get the total number of ships enabled for gameplay. Can be used in conjunction with getShipByIndex for iteration */
  function getTotalOwnedShips(address owner) public view returns (uint256) {
    return ownedShips[owner].length;
  }

  /**
    @dev This function is used for enabling a ship for gameplay that is not currently
    owned by this smart contract. The user must approve this contract to transfer the 
    ship on their behalf. A planet ID is required. 
   */

  function addShip(
    uint256 shipId,
    uint256 planetId,
    address owner
  ) external onlyGameContract nonReentrant whenNotPaused {
    // Verify that the sender is the owner of the ship
    require(SHIPS.ownerOf(shipId) == owner, "Not owner of ship");
    require(
      ships[shipId].exists == false,
      "Already exists. Use updateShip function"
    );
    // Verify that the planet is in game
    require(planets[planetId].exists, "Planet not in game");
    // Verify that this contract can transfer the ship
    require(
      SHIPS.getApproved(shipId) == address(this) ||
        SHIPS.isApprovedForAll(owner, address(this)),
      "Approve game contract"
    );
    _allShips.push(shipId);
    uint256 len = _allShips.length;
    uint256 currentEpoch = _setEpoch();
    shipsOnPlanet[planetId].push(shipId);
    uint256 numShipsOnPlanet = shipsOnPlanet[planetId].length;

    // If this ship has been used before in game then it will have landed on a
    // planet. The person adding the ship will need to pay the travel cost to
    // land on the new planet.
    if (reentryLocation[shipId] != 0 && reentryLocation[shipId] != planetId) {
      _chargeTravelCost(reentryLocation[shipId], planetId, owner);
    }

    ships[shipId] = Ship({
      exists: true,
      mining: false,
      piratePending: false,
      travelingUntil: 0,
      disabledUntil: 0,
      travelingFrom: 0,
      startEpoch: currentEpoch,
      endEpoch: currentEpoch,
      planetId: planetId,
      shipId: shipId,
      idx: len - 1,
      planetIdx: numShipsOnPlanet - 1,
      owner: owner
    });

    ownedShips[owner].push(shipId);
    uint256 ownedLen = ownedShips[owner].length;
    ownedShipIndex[shipId] = ownedLen - 1;
    SHIPS.transferFrom(owner, address(this), shipId);
  }

  mapping(uint256 => uint256) public reentryLocation;

  function _deleteShipData(uint256 shipId, address sender) internal {
    Ship memory ship = ships[shipId];
    // delete from ownedShips array
    // replace item with last item in array
    ownedShips[sender][ownedShipIndex[shipId]] = ownedShips[sender][
      ownedShips[sender].length - 1
    ];
    // remove last item
    ownedShips[sender].pop();

    // delete from ownerShipIndex
    delete ownedShipIndex[shipId];
    // delete from all ships
    _allShips[ship.idx] = _allShips[_allShips.length - 1];
    _allShips.pop();

    // delete from ships on planet
    shipsOnPlanet[ship.planetId][ship.planetIdx] =
      shipsOnPlanet[ship.planetId].length -
      1;
    shipsOnPlanet[ship.planetId].pop();
    reentryLocation[shipId] = ship.planetId;
    delete ships[shipId];
  }

  function removeShip(
    uint256 shipId,
    address sender,
    bool risky
  ) external onlyGameContract nonReentrant whenNotPaused {
    _setEpoch();
    // Claim function verifies that shipId is owned by sender
    claim(shipId, sender, risky);
    _deleteShipData(shipId, sender);
  }

  function addPlanet(uint256 planetId, address owner)
    external
    onlyGameContract
    nonReentrant
    whenNotPaused
  {
    // Verify that the sender is the owner of the planet
    require(PLANETS.ownerOf(planetId) == owner, "Not owner of planet");
    // Verify planet not already in contract
    require(planets[planetId].exists == false, "Planet already exists");
    // Verify that this contract can transfer the ship
    require(
      PLANETS.getApproved(planetId) == address(this) ||
        PLANETS.isApprovedForAll(owner, address(this)),
      "Approve game contract"
    );
    _allPlanets.push(planetId);
    uint256 len = _allPlanets.length;
    planets[planetId] = Planet({
      exists: true,
      planetId: planetId,
      idx: len - 1,
      owner: owner,
      miningShipId: 0,
      pendingClaim: false
    });

    ownedPlanets[owner].push(planetId);
    uint256 ownedLen = ownedPlanets[owner].length;
    ownedPlanetIndex[planetId] = ownedLen - 1;
    PLANETS.safeTransferFrom(owner, address(this), planetId);
  }

  function _deletePlanet(uint256 planetId, address sender) internal {
    Planet memory planet = planets[planetId];
    // delete from ownedShips array
    // replace item with last item in array
    ownedPlanets[sender][ownedPlanetIndex[planetId]] = ownedPlanets[sender][
      ownedPlanets[sender].length - 1
    ];
    // remove last item
    ownedPlanets[sender].pop();

    // delete from ownerShipIndex
    delete ownedPlanetIndex[planetId];
    // delete from all ships
    _allPlanets[planet.idx] = _allPlanets[_allPlanets.length - 1];
    _allPlanets.pop();

    delete planets[planetId];
  }

  /**
    @dev function to remove planet from game play.
    If there is a ship mining this planet the mining will cease.
   */
  function removePlanet(uint256 planetId, address sender)
    external
    onlyGameContract
    nonReentrant
    whenNotPaused
  {
    require(planets[planetId].owner == sender, "Unauthorized");
    require(planets[planetId].pendingClaim == false, "Planet pending claim");
    uint256 currentEpoch = _setEpoch();
    uint256 shipId = planets[planetId].miningShipId;
    if (shipId != 0 && ships[shipId].mining) {
      ships[shipId].mining = false;
      ships[shipId].endEpoch = currentEpoch;
    }
    _deletePlanet(planetId, sender);
    PLANETS.safeTransferFrom(address(this), sender, planetId);
  }

  function calculateMiningPower(uint256 shipId, uint256 planetId)
    public
    view
    returns (uint256)
  {
    StarShips.Ship memory shipParams = SHIPS.getShipParams(shipId);
    PixelglyphPlanets.Planet memory planetParams = PLANETS.getPlanetParams(
      planetId
    );

    uint256 max;

    // subsurface
    max = shipParams.toolStrength * planetParams.resourceDepth;

    // bio mine
    uint256 bioMine = shipParams.labCapacity * planetParams.biodiversity;
    if (bioMine > max) {
      max = bioMine;
    }

    // laser
    uint256 laser = shipParams.laserStrength * planetParams.albedo;
    if (laser > max) {
      max = laser;
    }

    return max;
  }

  function beginMining(uint256 shipId, address sender)
    external
    onlyGameContract
    nonReentrant
    whenNotPaused
  {
    require(ships[shipId].exists == true, "Add ship");
    uint256 planetId = ships[shipId].planetId;
    require(planets[planetId].exists == true, "Add planet");
    require(ships[shipId].owner == sender, "Not ship owner");
    require(planets[planetId].owner == sender, "Not planet owner");
    require(ships[shipId].mining == false, "Ship already mining");

    totalMiningPower += calculateMiningPower(shipId, planetId);
    uint256 currentEpoch = _setEpoch();
    ships[shipId].mining = true;
    ships[shipId].startEpoch = currentEpoch;
    planets[planetId].miningShipId = shipId;
  }

  function getCurrentEpoch() public view returns (uint256) {
    return (block.timestamp - START_TIME) / (4 hours) + 1;
  }

  uint256 DELTA_CALC_NUMERATOR = 249;
  uint256 DELTA_CALC_DENOMINATOR = 250;

  function updateDeltaCalc(uint256 num, uint256 denom) public onlyOwner {
    DELTA_CALC_NUMERATOR = num;
    DELTA_CALC_DENOMINATOR = denom;
  }

  // (balance * (1 - 0.996 ** 2))
  // 1 - 0.996 ** 2 = 0.007984
  //
  // 0.992016

  // 120000000 * (1 - 0.996 ** 1) = 480,000

  function _getRewardsForDelta(uint256 delta) internal view returns (uint256) {
    uint256 balance = (EL69.balanceOf(address(this)) - pirateEscrowBalance) /
      10**18;
    int128 intBalance = ABDKMath64x64.fromUInt(balance);
    int128 a = int128(249).divi(250);
    int128 b = a.pow(delta);
    int128 c = int128(1).fromInt().sub(b);
    int128 d = c.mul(intBalance);
    return d.toUInt();
    // return
    //   balance -
    //   (balance * DELTA_CALC_NUMERATOR**delta) /
    //   DELTA_CALC_DENOMINATOR**delta;
  }

  function getRewardsForDelta(uint256 d) public view returns (uint256) {
    return _getRewardsForDelta(d);
  }

  mapping(uint256 => uint256) public epochIdx;

  event EpochSaved(uint256 epoch);

  function _setEpoch() internal returns (uint256) {
    uint256 epoch = getCurrentEpoch();
    if (lastSavedEpoch < epoch) {
      uint256 delta = epoch - lastSavedEpoch;
      uint256 totalRewardsAtEpoch = _getRewardsForDelta(delta);
      uint256 rewardPerMiningPower = totalMiningPower > 0
        ? totalRewardsAtEpoch / totalMiningPower
        : 0;
      epochIdx[epoch] = miningPowerRewardPerEpoch.arr.length;
      miningPowerRewardPerEpoch.increase(
        miningPowerRewardPerEpoch.arr.length,
        rewardPerMiningPower
      );
      lastSavedEpoch = epoch;
      emit EpochSaved(epoch);
    }
    return epoch;
  }

  function getRandomNumber() public returns (bytes32 requestId) {
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
    return requestRandomness(keyHash, fee);
  }

  event Awarded(
    address indexed awardee,
    uint256 maxAmount,
    uint256 awardedAmount
  );

  event Pirated(
    address indexed pirate,
    address indexed owner,
    uint256 indexed planetId,
    bool success
  );

  /**
   * Callback function used by VRF Coordinator
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness)
    internal
    override
  {
    // Claim
    if (reqIdTypes[requestId] == 1) {
      Claim memory claimReq = claimRequests[requestId];
      planets[claimReq.planetId].pendingClaim = false;
      uint256 awardedAmount;
      if (claimReq.risky) {
        PixelglyphPlanets.Planet memory planetParams = PLANETS.getPlanetParams(
          claimReq.planetId
        );
        uint256 a = planetParams.geologicalInstability * 10**18;
        uint256 b = 1000 * 10**18;
        uint256 c = a - b;

        uint256 d = (randomness % 100) + 1;
        bool destruct = (d * 10**18) / 100 >= (c / 3000 / 100);
        if (destruct) {
          PLANETS.burn(claimReq.planetId);
        } else {
          awardedAmount = claimReq.amount;
          bonuses[claimReq.claimer] += awardedAmount;
        }
      } else {
        awardedAmount = claimReq.amount * (((randomness % 100) + 1) / 100);
        bonuses[claimReq.claimer] += awardedAmount;
      }

      emit Awarded(claimReq.claimer, claimReq.amount, awardedAmount);
    }

    // Pirate
    if (reqIdTypes[requestId] == 2) {
      Pirate memory pirateReq = pirateRequests[requestId];
      StarShips.Ship memory shipParams = SHIPS.getShipParams(pirateReq.shipId);
      PixelglyphPlanets.Planet memory planetParams = PLANETS.getPlanetParams(
        pirateReq.planetId
      );
      //  (weapons/defenses)*0.24 - 0.01;
      uint256 x = (shipParams.groundWeapons * 10**18) /
        planetParams.groundDefenses;
      uint256 a = ((x * 6) / 25) - 0.01 * 10**18;
      uint256 b = (randomness % 100) + 1;
      bool succeeded = a >= ((b * 10**18) / 100);
      address currentOwner = planets[pirateReq.planetId].owner;
      if (succeeded) {
        // Transfer funds back to pirate
        EL69.transferFrom(address(this), pirateReq.pirate, pirateReq.price);
        // Transfer ownership of planet to pirate
        _transferPlanetOwnership(pirateReq.planetId, pirateReq.pirate);
      } else {
        // Transfer funds back to pirate minus 0.5%
        uint256 loss = pirateReq.price / 1 / 200;
        uint256 amount = pirateReq.price - loss;
        ships[pirateReq.shipId].disabledUntil = block.timestamp + 1 days;
        EL69.transferFrom(address(this), pirateReq.pirate, amount);
      }
      emit Pirated(
        pirateReq.pirate,
        currentOwner,
        pirateReq.planetId,
        succeeded
      );
    }
  }

  function _transferPlanetOwnership(uint256 planetId, address newOwner)
    internal
  {
    // replace the planet with the last planet in the array
    ownedPlanets[planets[planetId].owner][
      ownedPlanetIndex[planetId]
    ] = ownedPlanets[planets[planetId].owner][
      ownedPlanets[planets[planetId].owner].length - 1
    ];
    ownedPlanets[planets[planetId].owner].pop();
    ownedPlanets[newOwner].push(planetId);
    ownedPlanetIndex[planetId] = ownedPlanets[newOwner].length - 1;
    planets[planetId].owner = newOwner;
  }

  uint256 MAX_UINT = 2**256 - 1;

  struct Claim {
    uint256 amount;
    uint256 planetId;
    address claimer;
    bool risky;
  }

  mapping(bytes32 => Claim) claimRequests;

  mapping(address => uint256) public bonuses;

  // 1 - Claim
  // 2 - Pirate
  mapping(bytes32 => uint256) reqIdTypes;

  /**
    @dev Claim EL69 for a given ship. Guaranteed amount will be sent immediately, 
    while randomized amount will be available upon completion of fulfillRandomness function. 
   */
  function claim(
    uint256 shipId,
    address sender,
    bool risky
  ) public onlyGameContract nonReentrant whenNotPaused {
    require(ships[shipId].exists, "Ship does not exist");
    require(ships[shipId].owner == sender, "Sender not owner");
    uint256 currentEpoch = _setEpoch();
    if (ships[shipId].startEpoch >= ships[shipId].endEpoch) {
      // Nothing to claim
      return;
    }
    uint256 rewardsForRange = _getClaimMax(shipId, currentEpoch);
    uint256 split = rewardsForRange / 2;
    bytes32 requestId = getRandomNumber();
    claimRequests[requestId] = Claim({
      amount: split,
      claimer: sender,
      planetId: ships[shipId].planetId,
      risky: risky
    });
    planets[ships[shipId].planetId].pendingClaim = true;
    reqIdTypes[requestId] = 1;
    ships[shipId].startEpoch = currentEpoch + 1;
    EL69.transfer(sender, split);
  }

  /**
    @dev Function that returns the max reward for a given ship ID. We use the last saved epoch to calculate range.
    For viewing purposes the last saved epoch may be out of date. 1 or more epochs may have passed since the last
    saved epoch. 
   */
  function _getClaimMax(uint256 shipId, uint256 currentEpoch)
    internal
    returns (uint256)
  {
    require(ships[shipId].exists, "Ship does not exist");
    if (ships[shipId].mining && currentEpoch > ships[shipId].endEpoch) {
      ships[shipId].endEpoch = currentEpoch;
    }
    return
      calculateMiningPower(shipId, ships[shipId].planetId) *
      miningPowerRewardPerEpoch.queryRange(
        epochIdx[ships[shipId].startEpoch],
        epochIdx[ships[shipId].endEpoch]
      );
  }

  /**
    @dev Function that returns the max reward for a given ship ID. This is a function that can be used to display the estimated reward
    on the front end. The difference between this function and getClaimMax is that if last saved epoch is outdated then we calculate the
    reward on the fly. _getClaimMax updates the ship endEpoch to current epoch if needed. 
   */
  function getClaimableAmount(uint256 shipId) public view returns (uint256) {
    uint256 currentEpoch = getCurrentEpoch();
    Ship memory ship = ships[shipId];
    require(ship.exists, "Ship does not exist");
    require(
      ship.startEpoch < (ship.mining ? currentEpoch : ship.endEpoch),
      "Cannot claim"
    );
    uint256 miningPower = calculateMiningPower(shipId, ships[shipId].planetId);
    // If the ship is not mining then we can return the rewards for the mining start and stop epoch of the ship
    if (!ship.mining) {
      return
        miningPower *
        miningPowerRewardPerEpoch.queryRange(
          epochIdx[ship.startEpoch],
          epochIdx[ship.endEpoch]
        );
    }
    // If the ship is mining then we check to see if the current epoch is greater than the last saved epoch
    // if it is then we will calculate the additional possible rewards on the fly.
    else {
      // If the end epoch of the ship is less than the current epoch then we need to calculate
      // the remaining rewards
      if (ship.endEpoch < currentEpoch) {
        // If the last saved epoch is outdated then we need to calculate the rewards for the missing epochs
        if (currentEpoch > lastSavedEpoch) {
          // get the total rewards spanning the ship start epoch to the last saved epoch
          uint256 totalNotedRewards = miningPowerRewardPerEpoch.queryRange(
            epochIdx[ship.startEpoch],
            epochIdx[lastSavedEpoch]
          );
          // get additional rewards that have yet to be noted.
          uint256 totalRewardsAtEpoch = _getRewardsForDelta(
            currentEpoch - lastSavedEpoch
          );
          uint256 rewardPerMiningPower = totalRewardsAtEpoch / totalMiningPower;
          uint256 total = totalNotedRewards + rewardPerMiningPower;
          return miningPower * total;
        }
        // if the current epoch is the same as the last saved epoch then we can use that as the end place
        else {
          return
            miningPower *
            miningPowerRewardPerEpoch.queryRange(
              epochIdx[ship.startEpoch],
              epochIdx[lastSavedEpoch]
            );
        }
      } else {
        return
          miningPower *
          miningPowerRewardPerEpoch.queryRange(
            epochIdx[ship.startEpoch],
            epochIdx[ship.endEpoch]
          );
      }
    }
  }

  function sqrt(uint256 y) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    }
  }

  /**
    @dev This function is used to get the distance between two planets. The cost to travel can be calculated by multiplying 
    the distance by the PRICE_PER_DISTANCE.
   */
  function getDistance(uint256 planetAId, uint256 planetBId)
    public
    view
    returns (uint256)
  {
    PixelglyphPlanets.Planet memory planetA = PLANETS.getPlanetParams(
      planetAId
    );
    PixelglyphPlanets.Planet memory planetB = PLANETS.getPlanetParams(
      planetBId
    );
    return sqrt((planetA.x - planetB.x)**2 + (planetA.y - planetB.y)**2);
  }

  function _chargeTravelCost(
    uint256 from,
    uint256 to,
    address sender
  ) internal {
    uint256 distance = getDistance(from, to);
    uint256 price = distance * PRICE_PER_DISTANCE;
    EL69.transferFrom(sender, address(this), price);
  }

  function _checkShipDisabled(uint256 shipId) internal view {
    require(ships[shipId].piratePending == false, "Pirate pending");
    require(ships[shipId].disabledUntil <= block.timestamp, "Ship disabled");
  }

  /**
    @dev function used to move ship from planet A to planet B. Sender must have approved this contract to spend EL69.
    Should calculate price per distance on front end and display error if this contract cannot transfer required amount,
    or the user does not have enough funds to travel.
    @param shipId The ID of the ship to move
    @param planetId The ID of the planet to travel to
    @param sender The owner of the ship
   */
  function travel(
    uint256 shipId,
    uint256 planetId,
    address sender
  ) public nonReentrant onlyGameContract {
    Ship memory ship = ships[shipId];
    require(ship.exists == true, "Invalid ship ID");
    require(ship.owner == sender, "Sender not owner");
    require(planets[planetId].exists == true, "Invalid planet ID");
    _checkShipDisabled(shipId);
    _chargeTravelCost(ship.planetId, planetId, sender);
    ship.planetId = planetId;

    uint256 currentEpoch = _setEpoch();
    bool isMiningUponArrival = planets[planetId].owner == sender;
    // If the ship is not mining when landing on the planet then we set the endEpoch to the current epoch only if the ship was previously mining
    // otherwise we leave the end epoch untouched.
    if (!isMiningUponArrival && ship.mining) {
      ships[shipId].endEpoch = currentEpoch;
    }
    ships[shipId].mining = isMiningUponArrival;
  }

  // TODO: move this to another smart contract
  function updateBaseStealPrice(uint256 val) public onlyOwner {
    BASE_STEAL_PRICE = val;
  }

  struct Pirate {
    uint256 planetId;
    uint256 shipId;
    address pirate;
    uint256 price;
  }

  mapping(bytes32 => Pirate) public pirateRequests;

  /**
    @dev Function to get the steal price for a given ship and planet.
    Solidity doesn't play nice with decimals so we are converting where necessary 
    and then converting the return back to 18 decimal value. The equation we are converting is
    base * (0.933333 + defenses/weapons/3.75) 

    BASE_STEAL_PRICE should have 18 decimal point precision
   */
  function getStealPrice(uint256 shipId, uint256 planetId)
    public
    view
    returns (uint256)
  {
    StarShips.Ship memory shipParams = SHIPS.getShipParams(shipId);
    PixelglyphPlanets.Planet memory planetParams = PLANETS.getPlanetParams(
      planetId
    );

    uint256 a = 0.933333 * 10**18;
    uint256 b = ((planetParams.groundDefenses * 10**18) /
      shipParams.groundWeapons);
    uint256 c = (b / 375) * 100;
    return (BASE_STEAL_PRICE * (a + c)) / 10**18;
  }

  uint256 public pirateEscrowBalance;

  /**
    @dev Function to pirate a ship. Slippage tolerance should be calculated on front end. Example 10% slippage new BN('0.1').times(10**18).toFixed()
    Quoted price should be the price quoted to the potential pirate on the front end. 
    @param shipId ID of ship
    @param planetId ID of planet
    @param sender Address of sender
    @param slippageTolerance Slippage tolerance
    @param quotedPrice Price quoted to user
   */
  function pirate(
    uint256 shipId,
    uint256 planetId,
    address sender,
    uint256 slippageTolerance,
    uint256 quotedPrice
  ) external nonReentrant onlyGameContract {
    _setEpoch();
    Ship memory ship = ships[shipId];
    require(ship.exists == true, "Ship does not exist");
    _checkShipDisabled(shipId);
    require(ship.planetId == planetId, "Ship must be on planet");
    require(ship.owner != sender, "Already owned");
    require(planets[planetId].exists, "Planet does not exist");
    require(FF.planetIdToForceField(planetId) == 0, "Planet has force field");
    uint256 priceToSteal = getStealPrice(shipId, planetId);
    require(
      slippageTolerance <= (1 - quotedPrice / priceToSteal) * 10**18,
      "Price changed"
    );
    require(EL69.balanceOf(sender) >= priceToSteal, "Not enough funds");
    ships[shipId].piratePending = true;
    EL69.transferFrom(sender, address(this), priceToSteal);
    pirateEscrowBalance += priceToSteal;
    // What are we going to use to determine a successful pirate
    // Check to see if their is a forcefield
    bytes32 requestId = getRandomNumber();
    pirateRequests[requestId] = Pirate({
      planetId: planetId,
      shipId: shipId,
      pirate: sender,
      price: priceToSteal
    });
    reqIdTypes[requestId] = 2;
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external pure returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VRFRequestIDBase {
    /**
     * @notice returns the seed which is actually input to the VRF coordinator
     *
     * @dev To prevent repetition of VRF output due to repetition of the
     * @dev user-supplied seed, that seed is combined in a hash with the
     * @dev user-specific nonce, and the address of the consuming contract. The
     * @dev risk of repetition is mostly mitigated by inclusion of a blockhash in
     * @dev the final seed, but the nonce does protect against repetition in
     * @dev requests which are included in a single block.
     *
     * @param _userSeed VRF seed input provided by user
     * @param _requester Address of the requesting contract
     * @param _nonce User-specific nonce at the time of the request
     */
    function makeVRFInputSeed(
        bytes32 _keyHash,
        uint256 _userSeed,
        address _requester,
        uint256 _nonce
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(abi.encode(_keyHash, _userSeed, _requester, _nonce))
            );
    }

    /**
     * @notice Returns the id for this request
     * @param _keyHash The serviceAgreement ID to be used for this request
     * @param _vRFInputSeed The seed to be passed directly to the VRF
     * @return The id for this request
     *
     * @dev Note that _vRFInputSeed is not the seed passed by the consuming
     * @dev contract, but the one generated by makeVRFInputSeed
     */
    function makeRequestId(bytes32 _keyHash, uint256 _vRFInputSeed)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_keyHash, _vRFInputSeed));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LinkTokenInterface.sol";

import "./VRFRequestIDBase.sol";

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constuctor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator, _link) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash), and have told you the minimum LINK
 * @dev price for VRF service. Make sure your contract has sufficient LINK, and
 * @dev call requestRandomness(keyHash, fee, seed), where seed is the input you
 * @dev want to generate randomness from.
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomness method.
 *
 * @dev The randomness argument to fulfillRandomness is the actual random value
 * @dev generated from your seed.
 *
 * @dev The requestId argument is generated from the keyHash and the seed by
 * @dev makeRequestId(keyHash, seed). If your contract could have concurrent
 * @dev requests open, you can use the requestId to track which seed is
 * @dev associated with which randomness. See VRFRequestIDBase.sol for more
 * @dev details. (See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.)
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ. (Which is critical to making unpredictable randomness! See the
 * @dev next section.)
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the ultimate input to the VRF is mixed with the block hash of the
 * @dev block in which the request is made, user-provided seeds have no impact
 * @dev on its economic security properties. They are only included for API
 * @dev compatability with previous versions of this contract.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request.
 */
abstract contract VRFConsumerBase is VRFRequestIDBase {
    /**
     * @notice fulfillRandomness handles the VRF response. Your contract must
     * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
     * @notice principles to keep in mind when implementing your fulfillRandomness
     * @notice method.
     *
     * @dev VRFConsumerBase expects its subcontracts to have a method with this
     * @dev signature, and will call it once it has verified the proof
     * @dev associated with the randomness. (It is triggered via a call to
     * @dev rawFulfillRandomness, below.)
     *
     * @param requestId The Id initially returned by requestRandomness
     * @param randomness the VRF output
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        virtual;

    /**
     * @dev In order to keep backwards compatibility we have kept the user
     * seed field around. We remove the use of it because given that the blockhash
     * enters later, it overrides whatever randomness the used seed provides.
     * Given that it adds no security, and can easily lead to misunderstandings,
     * we have removed it from usage and can now provide a simpler API.
     */
    uint256 private constant USER_SEED_PLACEHOLDER = 0;

    /**
     * @notice requestRandomness initiates a request for VRF output given _seed
     *
     * @dev The fulfillRandomness method receives the output, once it's provided
     * @dev by the Oracle, and verified by the vrfCoordinator.
     *
     * @dev The _keyHash must already be registered with the VRFCoordinator, and
     * @dev the _fee must exceed the fee specified during registration of the
     * @dev _keyHash.
     *
     * @dev The _seed parameter is vestigial, and is kept only for API
     * @dev compatibility with older versions. It can't *hurt* to mix in some of
     * @dev your own randomness, here, but it's not necessary because the VRF
     * @dev oracle will mix the hash of the block containing your request into the
     * @dev VRF seed it ultimately uses.
     *
     * @param _keyHash ID of public key against which randomness is generated
     * @param _fee The amount of LINK to send with the request
     *
     * @return requestId unique ID for this request
     *
     * @dev The returned requestId can be used to distinguish responses to
     * @dev concurrent requests. It is passed as the first argument to
     * @dev fulfillRandomness.
     */
    function requestRandomness(bytes32 _keyHash, uint256 _fee)
        internal
        returns (bytes32 requestId)
    {
        LINK.transferAndCall(
            vrfCoordinator,
            _fee,
            abi.encode(_keyHash, USER_SEED_PLACEHOLDER)
        );
        // This is the seed passed to VRFCoordinator. The oracle will mix this with
        // the hash of the block containing this request to obtain the seed/input
        // which is finally passed to the VRF cryptographic machinery.
        uint256 vRFSeed = makeVRFInputSeed(
            _keyHash,
            USER_SEED_PLACEHOLDER,
            address(this),
            nonces[_keyHash]
        );
        // nonces[_keyHash] must stay in sync with
        // VRFCoordinator.nonces[_keyHash][this], which was incremented by the above
        // successful LINK.transferAndCall (in VRFCoordinator.randomnessRequest).
        // This provides protection against the user repeating their input seed,
        // which would result in a predictable/duplicate output, if multiple such
        // requests appeared in the same block.
        nonces[_keyHash] = nonces[_keyHash] + 1;
        return makeRequestId(_keyHash, vRFSeed);
    }

    LinkTokenInterface internal immutable LINK;
    address private immutable vrfCoordinator;

    // Nonces for each VRF key from which randomness has been requested.
    //
    // Must stay in sync with VRFCoordinator[_keyHash][this]
    mapping(bytes32 => uint256) /* keyHash */ /* nonce */
        private nonces;

    /**
     * @param _vrfCoordinator address of VRFCoordinator contract
     * @param _link address of LINK token contract
     *
     * @dev https://docs.chain.link/docs/link-token-contracts
     */
    constructor(address _vrfCoordinator, address _link) {
        vrfCoordinator = _vrfCoordinator;
        LINK = LinkTokenInterface(_link);
    }

    // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
    // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
    // the origin of the call
    function rawFulfillRandomness(bytes32 requestId, uint256 randomness)
        external
    {
        require(
            msg.sender == vrfCoordinator,
            "Only VRFCoordinator can fulfill"
        );
        fulfillRandomness(requestId, randomness);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
  Pixelglyph Star Ships
  by nftboi and tr666
 */

contract StarShips is ERC721Enumerable, Ownable, VRFConsumerBase {
  string BASE_URI;
  bytes32 keyHash;
  uint256 fee;
  uint256 public RANDOM;

  constructor(
    string memory baseUri,
    address _vrfCoordinator,
    address _linkToken,
    uint256 _vrfFee,
    bytes32 _keyHash
  ) ERC721("Star Ships", "") VRFConsumerBase(_vrfCoordinator, _linkToken) {
    BASE_URI = baseUri;
    keyHash = _keyHash;
    fee = _vrfFee;
  }

  uint256 globalId;

  mapping(uint256 => uint256) tokenIdToSeed;

  uint16[4] bodyLengths = [8, 9, 10, 11];
  uint16[3] bodyWidths = [8, 9, 10];
  uint16[4] blasterLengths = [12, 13, 14, 15];
  uint16[3] blasterWidths = [3, 4, 5];

  struct Ship {
    uint16 blastersLength;
    uint16 blastersWidth;
    uint16 bodyLength;
    uint16 bodyWidth;
    uint16 toolStrength;
    uint16 labCapacity;
    uint16 laserStrength;
    uint16 speed;
    uint16 fuelEfficiency;
    uint16 groundWeapons;
    uint16 spaceWeapons;
    string color1;
    string color2;
    string color3;
    string color4;
  }

  function getRandomNumber() public returns (bytes32 requestId) {
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
    return requestRandomness(keyHash, fee);
  }

  /**
   * Callback function used by VRF Coordinator
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness)
    internal
    override
  {
    if (RANDOM == 0) {
      RANDOM = randomness;
    }
  }

  function setBoolean(
    uint256 _packedBools,
    uint256 _boolNumber,
    uint256 _value
  ) public pure returns (uint256) {
    if (_value == 1) return _packedBools | (uint256(1) << _boolNumber);
    else return _packedBools & ~(uint256(1) << _boolNumber);
  }

  function getBoolean(uint256 _packedBools, uint256 _boolNumber)
    public
    pure
    returns (uint256)
  {
    uint256 flag = (_packedBools >> _boolNumber) & uint256(1);
    return flag;
  }

  function countNeighbors(
    uint256 id,
    uint256 bitPos,
    uint256 normalizedIndex,
    uint256 width,
    uint256 length
  ) public pure returns (uint256) {
    uint256 area = width * length;
    uint256 top = bitPos >= width ? getBoolean(id, bitPos - width) : 0;
    uint256 bottom = bitPos <= area - (width + 1)
      ? getBoolean(id, bitPos + width)
      : 0;
    uint256 left = bitPos > 0 && normalizedIndex != 0
      ? getBoolean(id, bitPos - 1)
      : 0;
    uint256 right = bitPos < area - 1 && normalizedIndex != width - 1
      ? getBoolean(id, bitPos + 1)
      : 0;
    return top + bottom + left + right;
  }

  function nextGeneration(
    uint256 id,
    uint256 width,
    uint256 length
  ) public pure returns (uint256) {
    uint256 nextId = id;
    for (uint256 i = 0; i < width * length; i++) {
      uint256 x = (i - ((i / width) * width));
      uint256 n = countNeighbors(nextId, i, x, width, length);
      uint256 cell = getBoolean(nextId, i);
      uint256 next;

      if (cell == 1) {
        if (n < 2) {
          next = 0;
        } else if (n == 2 || n == 3) {
          next = 1;
        } else if (n > 3) {
          next = 0;
        }
      } else if (n == 3) {
        next = 1;
      }

      nextId = setBoolean(nextId, i, next);
    }
    return nextId;
  }

  function getLayers(uint256 tokenId) public view returns (uint256[5] memory) {
    Ship memory ship = getShipParams(tokenId);

    return [
      getLayer(tokenId, ship.bodyWidth, ship.bodyLength, "body1"),
      getLayer(tokenId, ship.bodyWidth, ship.bodyLength, "body2"),
      getLayer(tokenId, ship.blastersWidth, ship.blastersLength, "blst1"),
      getLayer(tokenId, ship.blastersWidth, ship.blastersLength, "blst2"),
      getLayer(tokenId, ship.blastersWidth, ship.blastersLength, "blst3")
    ];
  }

  function getLayer(
    uint256 tokenId,
    uint256 width,
    uint256 length,
    string memory key
  ) internal view returns (uint256) {
    uint256 id1 = getInitialMatrix(tokenId, length, width, key);
    uint256 id2 = nextGeneration(id1, width, length);
    uint256 id3 = nextGeneration(id2, width, length);
    uint256 id4 = nextGeneration(id3, width, length);
    return id4;
  }

  function getInitialMatrix(
    uint256 tokenId,
    uint256 length,
    uint256 width,
    string memory key
  ) public view returns (uint256 matrixId) {
    uint256 seed = uint256(
      keccak256(abi.encodePacked(tokenIdToSeed[tokenId], key))
    );

    for (uint256 i = 0; i < length; i++) {
      for (uint256 j = 0; j < width; j++) {
        uint256 idx = j + (width * i);
        matrixId = setBoolean(
          matrixId,
          idx,
          uint256(uint8(uint8(seed >> (2 * idx)) % 2))
        );
      }
    }
  }

  function getTokenSeed(uint256 tokenId) public view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(tokenIdToSeed[tokenId], RANDOM)));
  }

  function getShipParams(uint256 tokenId) public view returns (Ship memory) {
    uint256 seed = getTokenSeed(tokenId);
    string memory base = uintToStr(uint256(uint16(seed >> 64) % 200));
    return
      Ship({
        blastersLength: blasterLengths[
          uint16(uint16(seed) % blasterLengths.length)
        ],
        blastersWidth: blasterWidths[
          uint16(uint16(seed >> 16) % blasterWidths.length)
        ],
        bodyLength: bodyLengths[
          uint16(uint16(seed >> 32) % bodyLengths.length)
        ],
        bodyWidth: bodyWidths[uint16(uint16(seed >> 48) % bodyWidths.length)],
        toolStrength: (uint16(seed >> 80) % (4000 - 1000 + 1)) + 1000,
        labCapacity: (uint16(seed >> 96) % (4000 - 1000 + 1)) + 1000,
        laserStrength: (uint16(seed >> 112) % (4000 - 1000 + 1)) + 1000,
        speed: (
          uint16(
            uint16(uint256(keccak256(abi.encode(seed, 1)))) % (4000 - 1000 + 1)
          )
        ) + 1000,
        groundWeapons: (
          uint16(
            uint16(uint256(keccak256(abi.encode(seed, 2)))) % (4000 - 1000 + 1)
          )
        ) + 1000,
        spaceWeapons: (
          uint16(
            uint16(uint256(keccak256(abi.encode(seed, 3)))) % (4000 - 1000 + 1)
          )
        ) + 1000,
        fuelEfficiency: (
          uint16(
            uint16(uint256(keccak256(abi.encode(seed, 4)))) % (4000 - 1000 + 1)
          )
        ) + 1000,
        color1: string(
          abi.encodePacked("rgb(", base, ",", base, ",", base, ")")
        ),
        color2: string(
          abi.encodePacked(
            "rgb(",
            uintToStr(uint256(uint16(seed >> 80) % 256)),
            ",",
            uintToStr(uint256(uint16(seed >> 96) % 256)),
            ",",
            uintToStr(uint256(uint16(seed >> 112) % 256)),
            ")"
          )
        ),
        color3: string(
          abi.encodePacked(
            "rgb(",
            uintToStr(uint256(uint16(seed >> 128) % 256)),
            ",",
            uintToStr(uint256(uint16(seed >> 144) % 256)),
            ",",
            uintToStr(uint256(uint16(seed >> 160) % 256)),
            ")"
          )
        ),
        color4: string(
          abi.encodePacked(
            "rgb(",
            uintToStr(uint256(uint16(seed >> 176) % 256)),
            ",",
            uintToStr(uint256(uint16(seed >> 192) % 256)),
            ",",
            uintToStr(uint256(uint16(seed >> 208) % 256)),
            ")"
          )
        )
      });
  }

  struct Config {
    uint256 layer;
    uint256 yOffset;
    uint256 width;
    uint256 length;
    uint256 area;
    bool isBase;
  }

  function getSvg(uint256 tokenId) public view returns (string memory) {
    uint256[5] memory layers = getLayers(tokenId);
    return _getSvg(tokenId, layers);
  }

  function _getSvg(uint256 tokenId, uint256[5] memory layers)
    internal
    view
    returns (string memory)
  {
    Ship memory ship = getShipParams(tokenId);
    string memory svg;
    string[5] memory parts;
    uint256 ppd = 12;
    uint256 size = 20;
    for (uint256 layerIdx = 0; layerIdx < layers.length; layerIdx++) {
      Config memory config = Config({
        layer: layers[layerIdx],
        yOffset: layerIdx < 2 ? 2 : 0,
        width: layerIdx < 2 ? ship.bodyWidth : ship.blastersWidth,
        length: layerIdx < 2 ? ship.bodyLength : ship.blastersLength,
        area: layerIdx < 2
          ? ship.bodyWidth * ship.bodyLength
          : ship.blastersLength * ship.blastersWidth,
        isBase: layerIdx < 2
      });

      for (uint256 y = 0; y < config.area; y++) {
        uint256 row = y / config.width;
        uint256 normalizedIdx = (y - row * config.width);
        uint256 bitPos = config.area - 1 - y;
        string memory color;
        if (getBoolean(config.layer, bitPos) == 1) {
          color = ship.color1;
        } else if (
          countNeighbors(
            config.layer,
            bitPos,
            config.width - 1 - normalizedIdx,
            config.width,
            config.length
          ) > 0
        ) {
          if (layerIdx == 0 || layerIdx == 2) {
            // c2
            color = ship.color2;
          } else if (layerIdx == 1 || layerIdx == 3) {
            color = ship.color3;
          } else {
            color = ship.color4;
          }
        } else {
          continue;
        }
        string memory rect = string(
          abi.encodePacked(
            '<rect shape-rendering="crispEdges" x="',
            uintToStr(normalizedIdx * ppd),
            '" y="',
            uintToStr((row + config.yOffset) * ppd),
            '" width="12" height="12" style="fill:',
            color,
            '"></rect>'
          )
        );
        string memory rectFlip = string(
          abi.encodePacked(
            '<rect shape-rendering="crispEdges" x="',
            uintToStr((size - normalizedIdx - 1) * ppd),
            '" y="',
            uintToStr((row + config.yOffset) * ppd),
            '" width="12" height="12" style="fill:',
            color,
            '"></rect>'
          )
        );

        parts[layerIdx] = string(
          abi.encodePacked(parts[layerIdx], rect, rectFlip)
        );
      }
    }

    svg = string(
      abi.encodePacked(
        '<svg version="1.1" width="500" height="500" xmlns="http://www.w3.org/2000/svg" transform="rotate(180)"><rect width="500" height=" 500" fill="#000" /><g transform="translate(',
        uintToStr((500 - size * ppd) / 2),
        " ",
        uintToStr((500 - ship.blastersLength * ppd) / 2),
        ')">',
        parts[0],
        parts[1],
        parts[2],
        parts[3],
        parts[4],
        "</g></svg>"
      )
    );

    return svg;
  }

  function _getSizeTraits(uint256 tokenId)
    internal
    view
    returns (string memory)
  {
    Ship memory ship = getShipParams(tokenId);
    return
      string(
        abi.encodePacked(
          '{"trait_type":"Width","value":',
          uintToStr(ship.blastersWidth + ship.bodyWidth),
          '},{"trait_type":"Length","value":',
          uintToStr(ship.blastersLength + ship.bodyLength),
          "},"
        )
      );
  }

  function _getColors(uint256 tokenId) internal view returns (string memory) {
    Ship memory ship = getShipParams(tokenId);
    return
      string(
        abi.encodePacked(
          '{"trait_type":"Color 4","value":"',
          ship.color4,
          '"},{"trait_type":"Color 3","value":"',
          ship.color3,
          '"},{"trait_type":"Color 2","value":"',
          ship.color2,
          '"},{"trait_type":"Color 1","value":"',
          ship.color1,
          '"},'
        )
      );
  }

  uint16 speed;
  uint16 fuelEfficiency;
  uint16 groundWeapons;
  uint16 spaceWeapons;

  function _getTraitPart(Ship memory ship)
    internal
    pure
    returns (string memory)
  {
    return
      string(
        abi.encodePacked(
          '}, {"trait_type":"Speed","value":',
          uintToStr(ship.speed),
          '}, {"trait_type":"Fuel Efficiency","value":',
          uintToStr(ship.fuelEfficiency),
          '}, {"trait_type":"Ground Weapons","value":',
          uintToStr(ship.groundWeapons),
          '}, {"trait_type":"Space Weapons","value":',
          uintToStr(ship.spaceWeapons),
          "}"
        )
      );
  }

  function _getTraits(uint256 tokenId) internal view returns (string memory) {
    Ship memory ship = getShipParams(tokenId);
    return
      string(
        abi.encodePacked(
          '"attributes": [',
          _getSizeTraits(tokenId),
          _getColors(tokenId),
          '{"trait_type":"Tool Strength","value":',
          uintToStr(ship.toolStrength),
          '}, {"trait_type":"Lab Capacity","value":',
          uintToStr(ship.labCapacity),
          '}, {"trait_type":"Laser Strength","value":',
          uintToStr(ship.laserStrength),
          _getTraitPart(ship),
          "]"
        )
      );
  }

  string PRE_REVEAL_URL =
    "https://ipfs.infura.io/ipfs/QmT2EHowdBGS4E2So4Wuzy3sybY8sMkgS6DBAmTUC4xRJN";

  function updatePreRevealUrl(string memory url) public onlyOwner {
    PRE_REVEAL_URL = url;
  }

  string DESCRIPTION =
    "Star Ship NFTs are vessels within the Pixelglyph P2E game. Use your Star Ship to mine Element 69. Star Ship NFTs also include a generative 3D Pixelglyph Invaders! space shooter game with generative visuals and audio. Ships live entirely on-chain. Go to https://www.invaders.wtf for more info.";

  function updateDescription(string memory desc) public onlyOwner {
    DESCRIPTION = desc;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    require(_exists(tokenId), "Token ID does not exist");
    if (RANDOM == 0) {
      return PRE_REVEAL_URL;
    }
    string memory id = uintToStr(tokenId);
    uint256[5] memory layers = getLayers(tokenId);

    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64.encode(
            bytes(
              string(
                abi.encodePacked(
                  '{"name": "Star Ship #',
                  id,
                  '", "description": "',
                  DESCRIPTION,
                  '",',
                  '"image": "data:image/svg+xml;base64,',
                  Base64.encode(bytes(_getSvg(tokenId, layers))),
                  '",',
                  _getTraits(tokenId),
                  ',"animation_url": "',
                  _animationUrl(tokenId, layers),
                  '"}'
                )
              )
            )
          )
        )
      );
  }

  mapping(address => bool) minters;
  event MinterUpdated(address minter, bool value);

  function setMinter(address minter, bool value) public onlyOwner {
    minters[minter] = value;
    emit MinterUpdated(minter, value);
  }

  function mint(address to, uint256[] memory ids) public {
    require(
      msg.sender == owner() || minters[msg.sender] == true,
      "Must be owner or minter"
    );
    for (uint256 i = 0; i < ids.length; i++) {
      uint256 tokenId = ids[i];
      tokenIdToSeed[tokenId] = uint256(
        keccak256(
          abi.encodePacked(tokenId, blockhash(block.number - 1), msg.sender)
        )
      );
      _safeMint(to, tokenId);
    }
  }

  function setBaseUri(string memory baseUri) public onlyOwner {
    BASE_URI = baseUri;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return BASE_URI;
  }

  function _getColorsForAnimationUrl(Ship memory ship)
    internal
    pure
    returns (string memory)
  {
    return
      string(
        abi.encodePacked(
          ',"color1":"',
          ship.color1,
          '","color2":"',
          ship.color2,
          '","color3":"',
          ship.color3,
          '","color4":"',
          ship.color4
        )
      );
  }

  function _layerString(uint256[5] memory layers)
    internal
    pure
    returns (string memory)
  {
    return
      string(
        abi.encodePacked(
          '"layers":[',
          uintToStr(layers[0]),
          ",",
          uintToStr(layers[1]),
          ",",
          uintToStr(layers[2]),
          ",",
          uintToStr(layers[3]),
          ",",
          uintToStr(layers[4]),
          "]"
        )
      );
  }

  function _animationUrl(uint256 tokenId, uint256[5] memory layers)
    internal
    view
    returns (string memory)
  {
    Ship memory ship = getShipParams(tokenId);
    return
      string(
        abi.encodePacked(
          _baseURI(),
          "?",
          Base64.encode(
            bytes(
              string(
                abi.encodePacked(
                  '{"params":{"blastersLength":',
                  uintToStr(ship.blastersLength),
                  ',"blastersWidth":',
                  uintToStr(ship.blastersWidth),
                  ',"bodyLength":',
                  uintToStr(ship.bodyLength),
                  ',"bodyWidth":',
                  uintToStr(ship.bodyWidth),
                  _getColorsForAnimationUrl(ship),
                  '"},',
                  _layerString(layers),
                  "}"
                )
              )
            )
          ),
          "+",
          uintToStr(tokenId)
        )
      );
  }

  function uintToStr(uint256 _i)
    internal
    pure
    returns (string memory _uintAsString)
  {
    if (_i == 0) {
      return "0";
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (_i != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
  }

  function withdrawLink(address to) public onlyOwner {
    LINK.transferFrom(address(this), to, LINK.balanceOf(address(this)));
  }

  function bytes32ToString(bytes32 x) internal pure returns (string memory) {
    bytes memory bytesString = new bytes(32);
    uint256 charCount = 0;
    for (uint256 j = 0; j < 32; j++) {
      bytes1 char = bytes1(bytes32(uint256(x) * 2**(8 * j)));
      if (char != 0) {
        bytesString[charCount] = char;
        charCount++;
      }
    }
    bytes memory bytesStringTrimmed = new bytes(charCount);
    for (uint256 j = 0; j < charCount; j++) {
      bytesStringTrimmed[j] = bytesString[j];
    }
    return string(bytesStringTrimmed);
  }
}

library Base64 {
  bytes internal constant TABLE =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  /// @notice Encodes some bytes to the base64 representation
  function encode(bytes memory data) internal pure returns (string memory) {
    uint256 len = data.length;
    if (len == 0) return "";

    // multiply by 4/3 rounded up
    uint256 encodedLen = 4 * ((len + 2) / 3);

    // Add some extra buffer at the end
    bytes memory result = new bytes(encodedLen + 32);

    bytes memory table = TABLE;

    assembly {
      let tablePtr := add(table, 1)
      let resultPtr := add(result, 32)

      for {
        let i := 0
      } lt(i, len) {

      } {
        i := add(i, 3)
        let input := and(mload(add(data, i)), 0xffffff)

        let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
        out := shl(8, out)
        out := add(
          out,
          and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
        )
        out := shl(8, out)
        out := add(
          out,
          and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
        )
        out := shl(8, out)
        out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
        out := shl(224, out)

        mstore(resultPtr, out)

        resultPtr := add(resultPtr, 4)
      }

      switch mod(len, 3)
      case 1 {
        mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
      }
      case 2 {
        mstore(sub(resultPtr, 1), shl(248, 0x3d))
      }

      mstore(result, encodedLen)
    }

    return string(result);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "./VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IForceField {
  function clearForceFieldFromPlanet(uint256 planetId) external;
}

contract PixelglyphPlanets is ERC721Enumerable, Ownable, VRFConsumerBase {
  string BASE_URI;
  bytes32 keyHash;
  uint256 fee;
  uint256 public RANDOM;
  address FF_ADDRESS;

  constructor(
    string memory baseUri,
    address _vrfCoordinator,
    address _linkToken,
    uint256 _vrfFee,
    bytes32 _keyHash
  )
    ERC721("Pixelglyph Planets", "")
    VRFConsumerBase(_vrfCoordinator, _linkToken)
  {
    BASE_URI = baseUri;
    keyHash = _keyHash;
    fee = _vrfFee;
  }

  function setFF(address ff) public onlyOwner {
    FF_ADDRESS = ff;
  }

  uint256 globalId;

  mapping(uint256 => uint256) tokenIdToSeed;

  struct Planet {
    uint256 resourceDepth;
    uint256 biodiversity;
    uint256 albedo;
    uint256 geologicalInstability;
    uint256 groundDefenses;
    uint256 spaceDefenses;
    uint256 x;
    uint256 y;
  }

  function getRandomNumber() public returns (bytes32 requestId) {
    require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
    return requestRandomness(keyHash, fee);
  }

  /**
   * Callback function used by VRF Coordinator
   */
  function fulfillRandomness(bytes32 requestId, uint256 randomness)
    internal
    override
  {
    if (RANDOM == 0) {
      RANDOM = randomness;
    }
  }

  function getTokenSeed(uint256 tokenId) public view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(tokenIdToSeed[tokenId], RANDOM)));
  }

  function burn(uint256 tokenId) public virtual {
    require(
      _isApprovedOrOwner(_msgSender(), tokenId),
      "ERC721Burnable: caller is not owner nor approved"
    );
    _burn(tokenId);
  }

  // TODO: Add sector
  // sector =  const sector = Math.floor(y / 100) * 100 + Math.floor(x / 100);
  function getPlanetParams(uint256 tokenId)
    public
    view
    returns (Planet memory)
  {
    uint256 seed = getTokenSeed(tokenId);
    return
      Planet({
        x: uint256(keccak256(abi.encode(seed, 1))) % 100_001,
        y: uint256(keccak256(abi.encode(seed, 2))) % 100_001,
        resourceDepth: (uint256(keccak256(abi.encode(seed, 3))) %
          (4000 - 1000 + 1)) + 1000,
        biodiversity: (uint256(keccak256(abi.encode(seed, 4))) %
          (4000 - 1000 + 1)) + 1000,
        albedo: (uint256(keccak256(abi.encode(seed, 5))) % (4000 - 1000 + 1)) +
          1000,
        geologicalInstability: (uint256(keccak256(abi.encode(seed, 6))) %
          (4000 - 1000 + 1)) + 1000,
        groundDefenses: (uint256(keccak256(abi.encode(seed, 7))) %
          (4000 - 1000 + 1)) + 1000,
        spaceDefenses: (uint256(keccak256(abi.encode(seed, 8))) %
          (4000 - 1000 + 1)) + 1000
      });
  }

  mapping(address => bool) public gameContract;

  function updateGameContract(address addr, bool value) public onlyOwner {
    gameContract[addr] = value;
  }

  mapping(address => bool) minters;
  event MinterUpdated(address minter, bool value);

  function setMinter(address minter, bool value) public onlyOwner {
    minters[minter] = value;
    emit MinterUpdated(minter, value);
  }

  function mint(address to, uint256[] memory ids) public {
    require(
      msg.sender == owner() || minters[msg.sender] == true,
      "Must be owner or minter"
    );
    for (uint256 i = 0; i < ids.length; i++) {
      uint256 tokenId = ids[i];
      tokenIdToSeed[tokenId] = uint256(
        keccak256(
          abi.encodePacked(tokenId, blockhash(block.number - 1), msg.sender)
        )
      );
      _safeMint(to, tokenId);
    }
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, tokenId);
    IForceField ff = IForceField(FF_ADDRESS);
    ff.clearForceFieldFromPlanet(tokenId);
  }

  function setBaseUri(string memory baseUri) public onlyOwner {
    BASE_URI = baseUri;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return BASE_URI;
  }

  function withdrawLink(address to) public onlyOwner {
    LINK.transferFrom(address(this), to, LINK.balanceOf(address(this)));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256 remaining);

    function approve(address spender, uint256 value)
        external
        returns (bool success);

    function balanceOf(address owner) external view returns (uint256 balance);

    function decimals() external view returns (uint8 decimalPlaces);

    function decreaseApproval(address spender, uint256 addedValue)
        external
        returns (bool success);

    function increaseApproval(address spender, uint256 subtractedValue)
        external;

    function name() external view returns (string memory tokenName);

    function symbol() external view returns (string memory tokenSymbol);

    function totalSupply() external view returns (uint256 totalTokensIssued);

    function transfer(address to, uint256 value)
        external
        returns (bool success);

    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool success);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool success);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library FenwickTree {
  struct Bit {
    uint256[] arr;
  }

  function increase(
    Bit storage self,
    uint256 position,
    uint256 value
  ) internal {
    if (position < 1 || position > self.arr.length) {
      revert("Position is out of allowed range");
    }

    uint256 i;
    for (i = position; i > 0; i -= i & (~i + 1)) {
      if (i >= self.arr.length) {
        self.arr.push(0);
      }
      self.arr[i] += value;
    }
  }

  function query(Bit storage self, uint256 position)
    internal
    view
    returns (uint256)
  {
    if (position < 1 || position > self.arr.length) {
      revert("Position is out of allowed range");
    }
    uint256 sum = 0;
    uint256 i;
    for (i = position; i < self.arr.length; i += i & (~i + 1)) {
      sum += self.arr[i];
    }
    return sum;
  }

  function queryRange(
    Bit storage self,
    uint256 leftIndex,
    uint256 rightIndex
  ) internal view returns (uint256) {
    if (leftIndex > rightIndex) {
      revert("Left index cannot be greater than right");
    }
    if (rightIndex == self.arr.length - 1) {
      return query(self, leftIndex);
    }

    return query(self, leftIndex) - query(self, rightIndex + 1);
  }
}

// SPDX-License-Identifier: BSD-4-Clause
/*
 * ABDK Math 64.64 Smart Contract Library.  Copyright © 2019 by ABDK Consulting.
 * Author: Mikhail Vladimirov <[email protected]>
 */
pragma solidity ^0.8.0;

/**
 * Smart contract library of mathematical functions operating with signed
 * 64.64-bit fixed point numbers.  Signed 64.64-bit fixed point number is
 * basically a simple fraction whose numerator is signed 128-bit integer and
 * denominator is 2^64.  As long as denominator is always the same, there is no
 * need to store it, thus in Solidity signed 64.64-bit fixed point numbers are
 * represented by int128 type holding only the numerator.
 */
library ABDKMath64x64 {
  /*
   * Minimum value signed 64.64-bit fixed point number may have.
   */
  int128 private constant MIN_64x64 = -0x80000000000000000000000000000000;

  /*
   * Maximum value signed 64.64-bit fixed point number may have.
   */
  int128 private constant MAX_64x64 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

  /**
   * Convert signed 256-bit integer number into signed 64.64-bit fixed point
   * number.  Revert on overflow.
   *
   * @param x signed 256-bit integer number
   * @return signed 64.64-bit fixed point number
   */
  function fromInt(int256 x) internal pure returns (int128) {
    unchecked {
      require(x >= -0x8000000000000000 && x <= 0x7FFFFFFFFFFFFFFF);
      return int128(x << 64);
    }
  }

  /**
   * Convert signed 64.64 fixed point number into signed 64-bit integer number
   * rounding down.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64-bit integer number
   */
  function toInt(int128 x) internal pure returns (int64) {
    unchecked {
      return int64(x >> 64);
    }
  }

  /**
   * Convert unsigned 256-bit integer number into signed 64.64-bit fixed point
   * number.  Revert on overflow.
   *
   * @param x unsigned 256-bit integer number
   * @return signed 64.64-bit fixed point number
   */
  function fromUInt(uint256 x) internal pure returns (int128) {
    unchecked {
      require(x <= 0x7FFFFFFFFFFFFFFF);
      return int128(int256(x << 64));
    }
  }

  /**
   * Convert signed 64.64 fixed point number into unsigned 64-bit integer
   * number rounding down.  Revert on underflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return unsigned 64-bit integer number
   */
  function toUInt(int128 x) internal pure returns (uint64) {
    unchecked {
      require(x >= 0);
      return uint64(uint128(x >> 64));
    }
  }

  /**
   * Convert signed 128.128 fixed point number into signed 64.64-bit fixed point
   * number rounding down.  Revert on overflow.
   *
   * @param x signed 128.128-bin fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function from128x128(int256 x) internal pure returns (int128) {
    unchecked {
      int256 result = x >> 64;
      require(result >= MIN_64x64 && result <= MAX_64x64);
      return int128(result);
    }
  }

  /**
   * Convert signed 64.64 fixed point number into signed 128.128 fixed point
   * number.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 128.128 fixed point number
   */
  function to128x128(int128 x) internal pure returns (int256) {
    unchecked {
      return int256(x) << 64;
    }
  }

  /**
   * Calculate x + y.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function add(int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      int256 result = int256(x) + y;
      require(result >= MIN_64x64 && result <= MAX_64x64);
      return int128(result);
    }
  }

  /**
   * Calculate x - y.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function sub(int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      int256 result = int256(x) - y;
      require(result >= MIN_64x64 && result <= MAX_64x64);
      return int128(result);
    }
  }

  /**
   * Calculate x * y rounding down.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function mul(int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      int256 result = (int256(x) * y) >> 64;
      require(result >= MIN_64x64 && result <= MAX_64x64);
      return int128(result);
    }
  }

  /**
   * Calculate x * y rounding towards zero, where x is signed 64.64 fixed point
   * number and y is signed 256-bit integer number.  Revert on overflow.
   *
   * @param x signed 64.64 fixed point number
   * @param y signed 256-bit integer number
   * @return signed 256-bit integer number
   */
  function muli(int128 x, int256 y) internal pure returns (int256) {
    unchecked {
      if (x == MIN_64x64) {
        require(
          y >= -0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF &&
            y <= 0x1000000000000000000000000000000000000000000000000
        );
        return -y << 63;
      } else {
        bool negativeResult = false;
        if (x < 0) {
          x = -x;
          negativeResult = true;
        }
        if (y < 0) {
          y = -y; // We rely on overflow behavior here
          negativeResult = !negativeResult;
        }
        uint256 absoluteResult = mulu(x, uint256(y));
        if (negativeResult) {
          require(
            absoluteResult <=
              0x8000000000000000000000000000000000000000000000000000000000000000
          );
          return -int256(absoluteResult); // We rely on overflow behavior here
        } else {
          require(
            absoluteResult <=
              0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
          );
          return int256(absoluteResult);
        }
      }
    }
  }

  /**
   * Calculate x * y rounding down, where x is signed 64.64 fixed point number
   * and y is unsigned 256-bit integer number.  Revert on overflow.
   *
   * @param x signed 64.64 fixed point number
   * @param y unsigned 256-bit integer number
   * @return unsigned 256-bit integer number
   */
  function mulu(int128 x, uint256 y) internal pure returns (uint256) {
    unchecked {
      if (y == 0) return 0;

      require(x >= 0);

      uint256 lo = (uint256(int256(x)) *
        (y & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) >> 64;
      uint256 hi = uint256(int256(x)) * (y >> 128);

      require(hi <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
      hi <<= 64;

      require(
        hi <=
          0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF -
            lo
      );
      return hi + lo;
    }
  }

  /**
   * Calculate x / y rounding towards zero.  Revert on overflow or when y is
   * zero.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function div(int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      require(y != 0);
      int256 result = (int256(x) << 64) / y;
      require(result >= MIN_64x64 && result <= MAX_64x64);
      return int128(result);
    }
  }

  /**
   * Calculate x / y rounding towards zero, where x and y are signed 256-bit
   * integer numbers.  Revert on overflow or when y is zero.
   *
   * @param x signed 256-bit integer number
   * @param y signed 256-bit integer number
   * @return signed 64.64-bit fixed point number
   */
  function divi(int256 x, int256 y) internal pure returns (int128) {
    unchecked {
      require(y != 0);

      bool negativeResult = false;
      if (x < 0) {
        x = -x; // We rely on overflow behavior here
        negativeResult = true;
      }
      if (y < 0) {
        y = -y; // We rely on overflow behavior here
        negativeResult = !negativeResult;
      }
      uint128 absoluteResult = divuu(uint256(x), uint256(y));
      if (negativeResult) {
        require(absoluteResult <= 0x80000000000000000000000000000000);
        return -int128(absoluteResult); // We rely on overflow behavior here
      } else {
        require(absoluteResult <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        return int128(absoluteResult); // We rely on overflow behavior here
      }
    }
  }

  /**
   * Calculate x / y rounding towards zero, where x and y are unsigned 256-bit
   * integer numbers.  Revert on overflow or when y is zero.
   *
   * @param x unsigned 256-bit integer number
   * @param y unsigned 256-bit integer number
   * @return signed 64.64-bit fixed point number
   */
  function divu(uint256 x, uint256 y) internal pure returns (int128) {
    unchecked {
      require(y != 0);
      uint128 result = divuu(x, y);
      require(result <= uint128(MAX_64x64));
      return int128(result);
    }
  }

  /**
   * Calculate -x.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function neg(int128 x) internal pure returns (int128) {
    unchecked {
      require(x != MIN_64x64);
      return -x;
    }
  }

  /**
   * Calculate |x|.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function abs(int128 x) internal pure returns (int128) {
    unchecked {
      require(x != MIN_64x64);
      return x < 0 ? -x : x;
    }
  }

  /**
   * Calculate 1 / x rounding towards zero.  Revert on overflow or when x is
   * zero.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function inv(int128 x) internal pure returns (int128) {
    unchecked {
      require(x != 0);
      int256 result = int256(0x100000000000000000000000000000000) / x;
      require(result >= MIN_64x64 && result <= MAX_64x64);
      return int128(result);
    }
  }

  /**
   * Calculate arithmetics average of x and y, i.e. (x + y) / 2 rounding down.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function avg(int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      return int128((int256(x) + int256(y)) >> 1);
    }
  }

  /**
   * Calculate geometric average of x and y, i.e. sqrt (x * y) rounding down.
   * Revert on overflow or in case x * y is negative.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function gavg(int128 x, int128 y) internal pure returns (int128) {
    unchecked {
      int256 m = int256(x) * int256(y);
      require(m >= 0);
      require(
        m < 0x4000000000000000000000000000000000000000000000000000000000000000
      );
      return int128(sqrtu(uint256(m)));
    }
  }

  /**
   * Calculate x^y assuming 0^0 is 1, where x is signed 64.64 fixed point number
   * and y is unsigned 256-bit integer number.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @param y uint256 value
   * @return signed 64.64-bit fixed point number
   */
  function pow(int128 x, uint256 y) internal pure returns (int128) {
    unchecked {
      bool negative = x < 0 && y & 1 == 1;

      uint256 absX = uint128(x < 0 ? -x : x);
      uint256 absResult;
      absResult = 0x100000000000000000000000000000000;

      if (absX <= 0x10000000000000000) {
        absX <<= 63;
        while (y != 0) {
          if (y & 0x1 != 0) {
            absResult = (absResult * absX) >> 127;
          }
          absX = (absX * absX) >> 127;

          if (y & 0x2 != 0) {
            absResult = (absResult * absX) >> 127;
          }
          absX = (absX * absX) >> 127;

          if (y & 0x4 != 0) {
            absResult = (absResult * absX) >> 127;
          }
          absX = (absX * absX) >> 127;

          if (y & 0x8 != 0) {
            absResult = (absResult * absX) >> 127;
          }
          absX = (absX * absX) >> 127;

          y >>= 4;
        }

        absResult >>= 64;
      } else {
        uint256 absXShift = 63;
        if (absX < 0x1000000000000000000000000) {
          absX <<= 32;
          absXShift -= 32;
        }
        if (absX < 0x10000000000000000000000000000) {
          absX <<= 16;
          absXShift -= 16;
        }
        if (absX < 0x1000000000000000000000000000000) {
          absX <<= 8;
          absXShift -= 8;
        }
        if (absX < 0x10000000000000000000000000000000) {
          absX <<= 4;
          absXShift -= 4;
        }
        if (absX < 0x40000000000000000000000000000000) {
          absX <<= 2;
          absXShift -= 2;
        }
        if (absX < 0x80000000000000000000000000000000) {
          absX <<= 1;
          absXShift -= 1;
        }

        uint256 resultShift = 0;
        while (y != 0) {
          require(absXShift < 64);

          if (y & 0x1 != 0) {
            absResult = (absResult * absX) >> 127;
            resultShift += absXShift;
            if (absResult > 0x100000000000000000000000000000000) {
              absResult >>= 1;
              resultShift += 1;
            }
          }
          absX = (absX * absX) >> 127;
          absXShift <<= 1;
          if (absX >= 0x100000000000000000000000000000000) {
            absX >>= 1;
            absXShift += 1;
          }

          y >>= 1;
        }

        require(resultShift < 64);
        absResult >>= 64 - resultShift;
      }
      int256 result = negative ? -int256(absResult) : int256(absResult);
      require(result >= MIN_64x64 && result <= MAX_64x64);
      return int128(result);
    }
  }

  /**
   * Calculate sqrt (x) rounding down.  Revert if x < 0.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function sqrt(int128 x) internal pure returns (int128) {
    unchecked {
      require(x >= 0);
      return int128(sqrtu(uint256(int256(x)) << 64));
    }
  }

  /**
   * Calculate binary logarithm of x.  Revert if x <= 0.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function log_2(int128 x) internal pure returns (int128) {
    unchecked {
      require(x > 0);

      int256 msb = 0;
      int256 xc = x;
      if (xc >= 0x10000000000000000) {
        xc >>= 64;
        msb += 64;
      }
      if (xc >= 0x100000000) {
        xc >>= 32;
        msb += 32;
      }
      if (xc >= 0x10000) {
        xc >>= 16;
        msb += 16;
      }
      if (xc >= 0x100) {
        xc >>= 8;
        msb += 8;
      }
      if (xc >= 0x10) {
        xc >>= 4;
        msb += 4;
      }
      if (xc >= 0x4) {
        xc >>= 2;
        msb += 2;
      }
      if (xc >= 0x2) msb += 1; // No need to shift xc anymore

      int256 result = (msb - 64) << 64;
      uint256 ux = uint256(int256(x)) << uint256(127 - msb);
      for (int256 bit = 0x8000000000000000; bit > 0; bit >>= 1) {
        ux *= ux;
        uint256 b = ux >> 255;
        ux >>= 127 + b;
        result += bit * int256(b);
      }

      return int128(result);
    }
  }

  /**
   * Calculate natural logarithm of x.  Revert if x <= 0.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function ln(int128 x) internal pure returns (int128) {
    unchecked {
      require(x > 0);

      return
        int128(
          int256(
            (uint256(int256(log_2(x))) * 0xB17217F7D1CF79ABC9E3B39803F2F6AF) >>
              128
          )
        );
    }
  }

  /**
   * Calculate binary exponent of x.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function exp_2(int128 x) internal pure returns (int128) {
    unchecked {
      require(x < 0x400000000000000000); // Overflow

      if (x < -0x400000000000000000) return 0; // Underflow

      uint256 result = 0x80000000000000000000000000000000;

      if (x & 0x8000000000000000 > 0)
        result = (result * 0x16A09E667F3BCC908B2FB1366EA957D3E) >> 128;
      if (x & 0x4000000000000000 > 0)
        result = (result * 0x1306FE0A31B7152DE8D5A46305C85EDEC) >> 128;
      if (x & 0x2000000000000000 > 0)
        result = (result * 0x1172B83C7D517ADCDF7C8C50EB14A791F) >> 128;
      if (x & 0x1000000000000000 > 0)
        result = (result * 0x10B5586CF9890F6298B92B71842A98363) >> 128;
      if (x & 0x800000000000000 > 0)
        result = (result * 0x1059B0D31585743AE7C548EB68CA417FD) >> 128;
      if (x & 0x400000000000000 > 0)
        result = (result * 0x102C9A3E778060EE6F7CACA4F7A29BDE8) >> 128;
      if (x & 0x200000000000000 > 0)
        result = (result * 0x10163DA9FB33356D84A66AE336DCDFA3F) >> 128;
      if (x & 0x100000000000000 > 0)
        result = (result * 0x100B1AFA5ABCBED6129AB13EC11DC9543) >> 128;
      if (x & 0x80000000000000 > 0)
        result = (result * 0x10058C86DA1C09EA1FF19D294CF2F679B) >> 128;
      if (x & 0x40000000000000 > 0)
        result = (result * 0x1002C605E2E8CEC506D21BFC89A23A00F) >> 128;
      if (x & 0x20000000000000 > 0)
        result = (result * 0x100162F3904051FA128BCA9C55C31E5DF) >> 128;
      if (x & 0x10000000000000 > 0)
        result = (result * 0x1000B175EFFDC76BA38E31671CA939725) >> 128;
      if (x & 0x8000000000000 > 0)
        result = (result * 0x100058BA01FB9F96D6CACD4B180917C3D) >> 128;
      if (x & 0x4000000000000 > 0)
        result = (result * 0x10002C5CC37DA9491D0985C348C68E7B3) >> 128;
      if (x & 0x2000000000000 > 0)
        result = (result * 0x1000162E525EE054754457D5995292026) >> 128;
      if (x & 0x1000000000000 > 0)
        result = (result * 0x10000B17255775C040618BF4A4ADE83FC) >> 128;
      if (x & 0x800000000000 > 0)
        result = (result * 0x1000058B91B5BC9AE2EED81E9B7D4CFAB) >> 128;
      if (x & 0x400000000000 > 0)
        result = (result * 0x100002C5C89D5EC6CA4D7C8ACC017B7C9) >> 128;
      if (x & 0x200000000000 > 0)
        result = (result * 0x10000162E43F4F831060E02D839A9D16D) >> 128;
      if (x & 0x100000000000 > 0)
        result = (result * 0x100000B1721BCFC99D9F890EA06911763) >> 128;
      if (x & 0x80000000000 > 0)
        result = (result * 0x10000058B90CF1E6D97F9CA14DBCC1628) >> 128;
      if (x & 0x40000000000 > 0)
        result = (result * 0x1000002C5C863B73F016468F6BAC5CA2B) >> 128;
      if (x & 0x20000000000 > 0)
        result = (result * 0x100000162E430E5A18F6119E3C02282A5) >> 128;
      if (x & 0x10000000000 > 0)
        result = (result * 0x1000000B1721835514B86E6D96EFD1BFE) >> 128;
      if (x & 0x8000000000 > 0)
        result = (result * 0x100000058B90C0B48C6BE5DF846C5B2EF) >> 128;
      if (x & 0x4000000000 > 0)
        result = (result * 0x10000002C5C8601CC6B9E94213C72737A) >> 128;
      if (x & 0x2000000000 > 0)
        result = (result * 0x1000000162E42FFF037DF38AA2B219F06) >> 128;
      if (x & 0x1000000000 > 0)
        result = (result * 0x10000000B17217FBA9C739AA5819F44F9) >> 128;
      if (x & 0x800000000 > 0)
        result = (result * 0x1000000058B90BFCDEE5ACD3C1CEDC823) >> 128;
      if (x & 0x400000000 > 0)
        result = (result * 0x100000002C5C85FE31F35A6A30DA1BE50) >> 128;
      if (x & 0x200000000 > 0)
        result = (result * 0x10000000162E42FF0999CE3541B9FFFCF) >> 128;
      if (x & 0x100000000 > 0)
        result = (result * 0x100000000B17217F80F4EF5AADDA45554) >> 128;
      if (x & 0x80000000 > 0)
        result = (result * 0x10000000058B90BFBF8479BD5A81B51AD) >> 128;
      if (x & 0x40000000 > 0)
        result = (result * 0x1000000002C5C85FDF84BD62AE30A74CC) >> 128;
      if (x & 0x20000000 > 0)
        result = (result * 0x100000000162E42FEFB2FED257559BDAA) >> 128;
      if (x & 0x10000000 > 0)
        result = (result * 0x1000000000B17217F7D5A7716BBA4A9AE) >> 128;
      if (x & 0x8000000 > 0)
        result = (result * 0x100000000058B90BFBE9DDBAC5E109CCE) >> 128;
      if (x & 0x4000000 > 0)
        result = (result * 0x10000000002C5C85FDF4B15DE6F17EB0D) >> 128;
      if (x & 0x2000000 > 0)
        result = (result * 0x1000000000162E42FEFA494F1478FDE05) >> 128;
      if (x & 0x1000000 > 0)
        result = (result * 0x10000000000B17217F7D20CF927C8E94C) >> 128;
      if (x & 0x800000 > 0)
        result = (result * 0x1000000000058B90BFBE8F71CB4E4B33D) >> 128;
      if (x & 0x400000 > 0)
        result = (result * 0x100000000002C5C85FDF477B662B26945) >> 128;
      if (x & 0x200000 > 0)
        result = (result * 0x10000000000162E42FEFA3AE53369388C) >> 128;
      if (x & 0x100000 > 0)
        result = (result * 0x100000000000B17217F7D1D351A389D40) >> 128;
      if (x & 0x80000 > 0)
        result = (result * 0x10000000000058B90BFBE8E8B2D3D4EDE) >> 128;
      if (x & 0x40000 > 0)
        result = (result * 0x1000000000002C5C85FDF4741BEA6E77E) >> 128;
      if (x & 0x20000 > 0)
        result = (result * 0x100000000000162E42FEFA39FE95583C2) >> 128;
      if (x & 0x10000 > 0)
        result = (result * 0x1000000000000B17217F7D1CFB72B45E1) >> 128;
      if (x & 0x8000 > 0)
        result = (result * 0x100000000000058B90BFBE8E7CC35C3F0) >> 128;
      if (x & 0x4000 > 0)
        result = (result * 0x10000000000002C5C85FDF473E242EA38) >> 128;
      if (x & 0x2000 > 0)
        result = (result * 0x1000000000000162E42FEFA39F02B772C) >> 128;
      if (x & 0x1000 > 0)
        result = (result * 0x10000000000000B17217F7D1CF7D83C1A) >> 128;
      if (x & 0x800 > 0)
        result = (result * 0x1000000000000058B90BFBE8E7BDCBE2E) >> 128;
      if (x & 0x400 > 0)
        result = (result * 0x100000000000002C5C85FDF473DEA871F) >> 128;
      if (x & 0x200 > 0)
        result = (result * 0x10000000000000162E42FEFA39EF44D91) >> 128;
      if (x & 0x100 > 0)
        result = (result * 0x100000000000000B17217F7D1CF79E949) >> 128;
      if (x & 0x80 > 0)
        result = (result * 0x10000000000000058B90BFBE8E7BCE544) >> 128;
      if (x & 0x40 > 0)
        result = (result * 0x1000000000000002C5C85FDF473DE6ECA) >> 128;
      if (x & 0x20 > 0)
        result = (result * 0x100000000000000162E42FEFA39EF366F) >> 128;
      if (x & 0x10 > 0)
        result = (result * 0x1000000000000000B17217F7D1CF79AFA) >> 128;
      if (x & 0x8 > 0)
        result = (result * 0x100000000000000058B90BFBE8E7BCD6D) >> 128;
      if (x & 0x4 > 0)
        result = (result * 0x10000000000000002C5C85FDF473DE6B2) >> 128;
      if (x & 0x2 > 0)
        result = (result * 0x1000000000000000162E42FEFA39EF358) >> 128;
      if (x & 0x1 > 0)
        result = (result * 0x10000000000000000B17217F7D1CF79AB) >> 128;

      result >>= uint256(int256(63 - (x >> 64)));
      require(result <= uint256(int256(MAX_64x64)));

      return int128(int256(result));
    }
  }

  /**
   * Calculate natural exponent of x.  Revert on overflow.
   *
   * @param x signed 64.64-bit fixed point number
   * @return signed 64.64-bit fixed point number
   */
  function exp(int128 x) internal pure returns (int128) {
    unchecked {
      require(x < 0x400000000000000000); // Overflow

      if (x < -0x400000000000000000) return 0; // Underflow

      return
        exp_2(int128((int256(x) * 0x171547652B82FE1777D0FFDA0D23A7D12) >> 128));
    }
  }

  /**
   * Calculate x / y rounding towards zero, where x and y are unsigned 256-bit
   * integer numbers.  Revert on overflow or when y is zero.
   *
   * @param x unsigned 256-bit integer number
   * @param y unsigned 256-bit integer number
   * @return unsigned 64.64-bit fixed point number
   */
  function divuu(uint256 x, uint256 y) private pure returns (uint128) {
    unchecked {
      require(y != 0);

      uint256 result;

      if (x <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        result = (x << 64) / y;
      else {
        uint256 msb = 192;
        uint256 xc = x >> 192;
        if (xc >= 0x100000000) {
          xc >>= 32;
          msb += 32;
        }
        if (xc >= 0x10000) {
          xc >>= 16;
          msb += 16;
        }
        if (xc >= 0x100) {
          xc >>= 8;
          msb += 8;
        }
        if (xc >= 0x10) {
          xc >>= 4;
          msb += 4;
        }
        if (xc >= 0x4) {
          xc >>= 2;
          msb += 2;
        }
        if (xc >= 0x2) msb += 1; // No need to shift xc anymore

        result = (x << (255 - msb)) / (((y - 1) >> (msb - 191)) + 1);
        require(result <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

        uint256 hi = result * (y >> 128);
        uint256 lo = result * (y & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

        uint256 xh = x >> 192;
        uint256 xl = x << 64;

        if (xl < lo) xh -= 1;
        xl -= lo; // We rely on overflow behavior here
        lo = hi << 128;
        if (xl < lo) xh -= 1;
        xl -= lo; // We rely on overflow behavior here

        assert(xh == hi >> 128);

        result += xl / y;
      }

      require(result <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
      return uint128(result);
    }
  }

  /**
   * Calculate sqrt (x) rounding down, where x is unsigned 256-bit integer
   * number.
   *
   * @param x unsigned 256-bit integer number
   * @return unsigned 128-bit integer number
   */
  function sqrtu(uint256 x) private pure returns (uint128) {
    unchecked {
      if (x == 0) return 0;
      else {
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) {
          xx >>= 128;
          r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
          xx >>= 64;
          r <<= 32;
        }
        if (xx >= 0x100000000) {
          xx >>= 32;
          r <<= 16;
        }
        if (xx >= 0x10000) {
          xx >>= 16;
          r <<= 8;
        }
        if (xx >= 0x100) {
          xx >>= 8;
          r <<= 4;
        }
        if (xx >= 0x10) {
          xx >>= 4;
          r <<= 2;
        }
        if (xx >= 0x8) {
          r <<= 1;
        }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return uint128(r < r1 ? r : r1);
      }
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "../../../utils/Context.sol";

/**
 * @title ERC721 Burnable Token
 * @dev ERC721 Token that can be irreversibly burned (destroyed).
 */
abstract contract ERC721Burnable is Context, ERC721 {
    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}