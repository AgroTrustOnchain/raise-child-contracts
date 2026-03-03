module raise_child::record;

use std::string::String;
use sui::clock::{Self, Clock};
use sui::event::{Self, emit};

const ENegativeAmount: u64 = 1;

public struct TransactionRecord has key {
    id: UID,
    actor_address: address,
    action_type: String,
    pool_name: String,
    message: String,
    amount: u64,
    coin_type: String,
    created_at: u64,
}

public struct TransactionRecordEvent has copy, drop {
    id: ID,
    actor_address: address,
    action_type: String,
    pool_name: String,
    message: String,
    amount: u64,
    coin_type: String,
    created_at: u64,
}

// public fun create_donate_sui_pool_record(
//     amount: u64,
//     clock: &Clock,
//     message: String,
//     ctx: &mut TxContext,
// ) {
//     let curTime = clock::timestamp_ms(clock);
//     let record = TransactionRecord {
//         id: object::new(ctx),
//         actor_address: ctx.sender(),
//         action_type: b"Deposit".to_string(),
//         amount: amount,
//         coin_type: b"SUI".to_string(),
//         message: message,
//         created_at: curTime,
//     };

//     event::emit(TransactionRecordEvent {
//         id: record.id.to_inner(),
//         actor_address: ctx.sender(),
//         action_type: b"Deposit".to_string(),
//         amount: amount,
//         coin_type: b"SUI".to_string(),
//         message: message,
//         created_at: curTime,
//     });

//     transfer::transfer(record, ctx.sender());
// }

// public fun create_withdraw_sui_pool_record(
//     amount: u64,
//     clock: &Clock,
//     message: String,
//     ctx: &mut TxContext,
// ) {
//     let curTime = clock::timestamp_ms(clock);
//     let record = TransactionRecord {
//         id: object::new(ctx),
//         actor_address: ctx.sender(),
//         action_type: b"Withdraw".to_string(),
//         amount: amount,
//         coin_type: b"SUI".to_string(),
//         message: message,
//         created_at: curTime,
//     };

//     transfer::transfer(record, ctx.sender());
// }

public(package) fun create_tx_record(
    amount: u64,
    coin_type: String,
    action_type: String,
    pool_name: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(amount > 0, ENegativeAmount);

    let cur_time = clock::timestamp_ms(clock);
    let actor = ctx.sender();

    let record = TransactionRecord {
        id: object::new(ctx),
        actor_address: actor,
        action_type: action_type,
        pool_name: pool_name,
        amount: amount,
        coin_type: coin_type,
        message: message,
        created_at: cur_time,
    };

    event::emit(TransactionRecordEvent {
        id: record.id.to_inner(),
        actor_address: actor,
        action_type: action_type,
        pool_name: pool_name,
        amount: amount,
        coin_type: coin_type,
        message: message,
        created_at: cur_time,
    });

    transfer::transfer(record, actor);
}

public(package) fun create_tx_record_v2(
    amount: u64,
    coin_type: String,
    action_type: String,
    pool_name: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    assert!(amount > 0, ENegativeAmount);

    let cur_time = clock::timestamp_ms(clock);
    let owner = ctx.sender();
    let record = TransactionRecord {
        id: object::new(ctx),
        actor_address: owner,
        action_type: action_type,
        pool_name: pool_name,
        amount: amount,
        coin_type: coin_type,
        message: message,
        created_at: cur_time,
    };

    let id = record.id.to_inner();

    event::emit(TransactionRecordEvent {
        id: id,
        actor_address: owner,
        action_type: action_type,
        pool_name: pool_name,
        amount: amount,
        coin_type: coin_type,
        message: message,
        created_at: cur_time,
    });

    transfer::transfer(record, owner);
    id
}

public(package) fun create_tx_record_with_address(
    amount: u64,
    coin_type: String,
    action_type: String,
    pool_name: String,
    message: String,
    clock: &Clock,
    owner: address,
    ctx: &mut TxContext,
) {
    assert!(amount > 0, ENegativeAmount);

    let cur_time = clock::timestamp_ms(clock);
    let record = TransactionRecord {
        id: object::new(ctx),
        actor_address: owner,
        action_type: action_type,
        pool_name: pool_name,
        amount: amount,
        coin_type: coin_type,
        message: message,
        created_at: cur_time,
    };

    event::emit(TransactionRecordEvent {
        id: record.id.to_inner(),
        actor_address: owner,
        action_type: action_type,
        pool_name: pool_name,
        amount: amount,
        coin_type: coin_type,
        message: message,
        created_at: cur_time,
    });

    transfer::transfer(record, owner);
}

public(package) fun create_tx_record_with_address_v2(
    amount: u64,
    coin_type: String,
    action_type: String,
    pool_name: String,
    message: String,
    clock: &Clock,
    owner: address,
    ctx: &mut TxContext,
): ID {
    assert!(amount > 0, ENegativeAmount);

    let cur_time = clock::timestamp_ms(clock);
    let record = TransactionRecord {
        id: object::new(ctx),
        actor_address: owner,
        action_type: action_type,
        pool_name: pool_name,
        amount: amount,
        coin_type: coin_type,
        message: message,
        created_at: cur_time,
    };

    let id = record.id.to_inner();

    event::emit(TransactionRecordEvent {
        id: id,
        actor_address: owner,
        action_type: action_type,
        pool_name: pool_name,
        amount: amount,
        coin_type: coin_type,
        message: message,
        created_at: cur_time,
    });

    transfer::transfer(record, owner);
    id
}
