# Smart Parking System Contract

A comprehensive on-chain parking management system built on the Stacks blockchain using Clarity smart contracts.

## Overview

The Smart Parking System enables decentralized parking spot management with features including spot registration, reservations, real-time check-in/check-out, automated payments, and statistics tracking. The system supports multiple parking spot types and includes penalty mechanisms for fair usage.

## Features

### Core Functionality
- **Parking Spot Management**: Add, update, and manage parking spots with different types
- **Reservation System**: Make advance reservations with automatic payment processing
- **Real-time Check-in/Check-out**: Seamless parking session management
- **Multi-tier Payment System**: Flexible pricing with owner revenue sharing
- **User Balance Management**: Deposit/withdraw funds with secure balance tracking
- **Statistics Tracking**: Comprehensive analytics for users and parking spots
- **Reputation System**: User scoring based on parking behavior

### Parking Spot Types
- **Regular** (`SPOT_TYPE_REGULAR`): Standard parking spots
- **Handicap** (`SPOT_TYPE_HANDICAP`): Accessible parking spaces
- **Electric** (`SPOT_TYPE_ELECTRIC`): EV charging stations
- **VIP** (`SPOT_TYPE_VIP`): Premium parking spaces

## Contract Architecture

### Data Structures

#### Parking Spots
```clarity
{
  owner: principal,
  location: string-ascii,
  spot-type: uint,
  hourly-rate: uint,
  is-occupied: bool,
  is-active: bool,
  current-user: optional principal,
  check-in-time: optional uint,
  reservation-id: optional uint
}
```

#### Reservations
```clarity
{
  user: principal,
  spot-id: uint,
  start-time: uint,
  end-time: uint,
  total-cost: uint,
  is-active: bool,
  is-used: bool
}
```

#### User Statistics
```clarity
{
  total-sessions: uint,
  total-spent: uint,
  total-penalties: uint,
  reputation-score: uint
}
```

### Key Constants

- **Base Hourly Rate**: 1 STX (1,000,000 microSTX)
- **Penalty Rate**: 0.5 STX per hour for insufficient balance
- **Maximum Reservation Duration**: 24 hours
- **Revenue Sharing**: 90% to spot owner, 10% to platform

## Public Functions

### Parking Spot Management

#### `add-parking-spot(location, spot-type, hourly-rate)`
Registers a new parking spot in the system.
- **Parameters**:
  - `location`: String description of parking spot location (max 100 chars)
  - `spot-type`: Type of parking spot (1-4)
  - `hourly-rate`: Cost per hour in microSTX
- **Returns**: Spot ID on success
- **Access**: Any user (becomes spot owner)

#### `update-parking-spot(spot-id, hourly-rate, is-active)`
Updates parking spot settings.
- **Parameters**:
  - `spot-id`: ID of the parking spot
  - `hourly-rate`: New hourly rate
  - `is-active`: Enable/disable spot
- **Access**: Spot owner only

### User Balance Management

#### `deposit-funds(amount)`
Deposits STX tokens to user's parking balance.
- **Parameters**:
  - `amount`: Amount in microSTX to deposit
- **Process**: Transfers STX to contract and updates user balance

#### `withdraw-funds(amount)`
Withdraws STX tokens from user's parking balance.
- **Parameters**:
  - `amount`: Amount in microSTX to withdraw
- **Requirements**: Sufficient balance required

### Reservation System

#### `make-reservation(spot-id, start-time, duration)`
Creates a parking reservation.
- **Parameters**:
  - `spot-id`: ID of desired parking spot
  - `start-time`: Reservation start time (block height)
  - `duration`: Duration in seconds
- **Requirements**: 
  - Sufficient balance
  - Spot availability
  - Valid time parameters
- **Returns**: Reservation ID

#### `cancel-reservation(reservation-id)`
Cancels an existing reservation.
- **Parameters**:
  - `reservation-id`: ID of reservation to cancel
- **Refund Policy**:
  - 80% refund if cancelled before start time
  - 0% refund if cancelled after start time
- **Access**: Reservation owner only

### Parking Sessions

#### `check-in(spot-id)`
Initiates a parking session.
- **Parameters**:
  - `spot-id`: ID of parking spot
- **Validation**: 
  - Checks for active reservations
  - Verifies spot availability
  - Validates user authorization
- **Returns**: Session ID

#### `check-out(spot-id)`
Ends a parking session and processes payment.
- **Parameters**:
  - `spot-id`: ID of parking spot
- **Process**:
  - Calculates total cost based on duration
  - Applies penalties for insufficient balance
  - Distributes payment to spot owner (90%) and platform (10%)
  - Updates user and spot statistics
- **Access**: Current spot user only

## Read-Only Functions

### Information Retrieval
- `get-parking-spot(spot-id)`: Retrieves spot details
- `get-reservation(reservation-id)`: Gets reservation information
- `get-user-balance(user)`: Returns user's current balance
- `get-user-statistics(user)`: Retrieves user statistics
- `get-spot-statistics(spot-id)`: Gets spot performance data

### Utility Functions
- `calculate-parking-cost(spot-id, duration)`: Calculates cost for given duration
- `is-spot-available(spot-id, start-time, end-time)`: Checks availability
- `get-current-time()`: Returns current block height
- `get-contract-balance()`: Total contract balance
- `get-base-hourly-rate()`: Current base rate
- `get-penalty-rate()`: Current penalty rate

## Administrative Functions

### `emergency-unlock(spot-id)`
Force unlocks a parking spot in emergency situations.
- **Access**: Contract owner only
- **Use Case**: System recovery, technical issues

### `set-base-rates(hourly-rate, penalty-rate)`
Updates system-wide base rates.
- **Access**: Contract owner only

### `set-max-reservation-duration(duration)`
Modifies maximum allowed reservation duration.
- **Access**: Contract owner only

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `ERR_UNAUTHORIZED` | Insufficient permissions |
| 101 | `ERR_SPOT_NOT_EXISTS` | Parking spot not found |
| 102 | `ERR_SPOT_OCCUPIED` | Spot currently occupied |
| 103 | `ERR_SPOT_NOT_OCCUPIED` | Spot not currently occupied |
| 104 | `ERR_INVALID_PAYMENT` | Invalid payment amount |
| 105 | `ERR_RESERVATION_EXISTS` | Reservation already exists |
| 106 | `ERR_RESERVATION_NOT_EXISTS` | Reservation not found |
| 107 | `ERR_RESERVATION_EXPIRED` | Reservation has expired |
| 108 | `ERR_INSUFFICIENT_BALANCE` | Insufficient user balance |
| 109 | `ERR_INVALID_TIME` | Invalid time parameters |
| 110 | `ERR_SPOT_DISABLED` | Parking spot disabled |
| 111 | `ERR_ALREADY_CHECKED_OUT` | Already checked out |
| 112 | `ERR_INVALID_SPOT_TYPE` | Invalid spot type |

## Usage Examples

### Basic Parking Session
```clarity
;; 1. Deposit funds
(contract-call? .smart-parking deposit-funds u5000000) ;; 5 STX

;; 2. Check into spot
(contract-call? .smart-parking check-in u1)

;; 3. Check out when done
(contract-call? .smart-parking check-out u1)
```

### Making a Reservation
```clarity
;; Make 4-hour reservation starting at block 1000
(contract-call? .smart-parking make-reservation u1 u1000 u14400)

;; Check in using reservation
(contract-call? .smart-parking check-in u1)
```

### Registering a Parking Spot
```clarity
;; Add electric vehicle charging spot
(contract-call? .smart-parking add-parking-spot 
  "Downtown Garage Level 2 Spot A1" 
  u3  ;; SPOT_TYPE_ELECTRIC
  u2000000) ;; 2 STX per hour
```

## Security Features

- **Access Control**: Function-level permissions for spot owners and contract admin
- **Balance Validation**: Prevents overdrafts and invalid transactions
- **Time Validation**: Ensures logical reservation and session timing
- **Penalty System**: Discourages abuse through reputation scoring
- **Emergency Controls**: Admin override capabilities for system recovery

## Economic Model

### Revenue Distribution
- **90%** to parking spot owners
- **10%** to platform (contract owner)

### Penalty System
- Applied when users have insufficient balance at checkout
- Rate: 0.5 STX per hour of shortfall
- Affects user reputation score

### Reputation System
- Starts at 100 points
- Penalties reduce score by 5%
- Good behavior increases score by 5%
- Maximum score capped at 200

## Development and Testing

### Prerequisites
- Clarinet CLI for local development
- Stacks blockchain testnet access
- Basic understanding of Clarity language

### Local Testing
```bash
clarinet check
clarinet test
clarinet console
```

### Deployment
```bash
clarinet deploy --network testnet
```