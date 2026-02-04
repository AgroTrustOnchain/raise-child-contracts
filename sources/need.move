module raise_child::need;

use raise_child::manage::{Manage, is_sponsor_added, add_sponsor_to_manage};
use raise_child::pool::{
    VndPool,
    LocalPool,
    mint_vnd,
    get_local_pool_region,
    add_amount_to_local_pool
};
use raise_child::record::create_tx_record_v2;
use raise_child::sponsor::{
    SponsorNFT,
    mint_sponsor_nft_v2,
    update_donation_after_donate,
    get_sponsor_id
};
use std::string::String;
use std::vector::push_back;
use sui::clock::{Self, Clock};

const ENotMatchedAmount: u64 = 1;
const ENeedSupported: u64 = 2;
const EInvalidSupportValue: u64 = 3;

public struct BooksNeed has key {
    id: UID,
    year: u64,
    year_changes: vector<u64>,
    semester: u64,
    value: u128,
    sponsors: vector<ID>,
    donations: vector<ID>,
}

public struct MealSupportDuration has store {
    start_period: String,
    end_period: String,
}

public struct MealNeed has key {
    id: UID,
    year: u64,
    value: u128,
    sponsors: vector<ID>,
    donations: vector<ID>,
    durations: vector<MealSupportDuration>,
}

public struct SpecialNeedProposal has key {
    id: UID,
    child: ID,
    creator: address,
    target: u128,
    description: String,
    approvers: vector<address>,
    refusers: vector<address>,
    approve_weight: u128,
    refuse_weight: u128,
    refuse_reasons: vector<String>,
    approved_periods: vector<u64>,
    refused_periods: vector<u64>,
    is_approved: bool,
    total_donated: u128,
    withdraw_amount: u128,
    donations: vector<ID>,
    withdraws: vector<ID>,
    created_at: u64,
    updated_at: u64,
    closed_at: u64,
}

// public struct SpecialNeedCampaign has key {
//     id: UID,
//     child: ID,
//     creator: address,
//     target: u128,
//     description: String,
//     total_donated: u128,
//     withdraw_amount: u128,
//     donations: vector<ID>,
//     withdraws: vector<ID>,
//     created_at: u64,
//     updated_at: u64,
// }

public(package) fun init_books_need(semester: u64, year: u64, ctx: &mut TxContext): ID {
    let need = BooksNeed {
        id: object::new(ctx),
        year: year,
        year_changes: vector[year],
        semester: semester,
        value: 0,
        sponsors: vector[],
        donations: vector[],
    };

    let id = need.id.to_inner();
    transfer::share_object(need);

    id
}

public(package) fun init_meal_need(year: u64, ctx: &mut TxContext): ID {
    let need = MealNeed {
        id: object::new(ctx),
        year: year,
        value: 0,
        sponsors: vector[],
        donations: vector[],
        durations: vector[],
    };

    let id = need.id.to_inner();
    transfer::share_object(need);

    id
}

public(package) fun support_books_need(
    need: &mut BooksNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    sponsor: &mut SponsorNFT,
    amount: u128,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(amount == need.value, ENotMatchedAmount);
    assert!(vector::length(&need.donations) < vector::length(&need.year_changes), ENeedSupported);

    let sponsor_id: ID;
    if (!is_sponsor_added(manage, ctx)) {
        sponsor_id =
            mint_sponsor_nft_v2(
                manage,
                first_name,
                last_name,
                gender,
                phone_number,
                email,
                amount,
                ctx,
            );
        add_sponsor_to_manage(manage, ctx);
    } else {
        update_donation_after_donate(sponsor, amount, ctx);
        sponsor_id = get_sponsor_id(sponsor);
    };

    mint_vnd(pool, amount, ctx);
    add_amount_to_local_pool(local_pool, amount);
    vector::push_back(
        &mut need.donations,
        create_tx_record_v2(
            amount,
            b"VND".to_string(),
            b"Support book need".to_string(),
            get_local_pool_region(local_pool),
            message,
            clock,
            ctx,
        ),
    );
    vector::push_back(&mut need.sponsors, sponsor_id);
}

public(package) fun support_meal_need(
    need: &mut MealNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    sponsor: &mut SponsorNFT,
    amount: u128,
    start_period: String,
    end_period: String,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let supported_months = amount / need.value;
    assert!(supported_months >= 1 && supported_months <= 12, EInvalidSupportValue);

    let sponsor_id: ID;
    if (!is_sponsor_added(manage, ctx)) {
        sponsor_id =
            mint_sponsor_nft_v2(
                manage,
                first_name,
                last_name,
                gender,
                phone_number,
                email,
                amount,
                ctx,
            );
        add_sponsor_to_manage(manage, ctx);
    } else {
        update_donation_after_donate(sponsor, amount, ctx);
        sponsor_id = get_sponsor_id(sponsor);
    };

    mint_vnd(pool, amount, ctx);
    add_amount_to_local_pool(local_pool, amount);
    vector::push_back(
        &mut need.donations,
        create_tx_record_v2(
            amount,
            b"VND".to_string(),
            b"Support book need".to_string(),
            get_local_pool_region(local_pool),
            message,
            clock,
            ctx,
        ),
    );
    vector::push_back(&mut need.sponsors, sponsor_id);
    vector::push_back(
        &mut need.durations,
        MealSupportDuration { start_period: start_period, end_period: end_period },
    );
}

public(package) fun get_books_need_id(need: &mut BooksNeed): ID {
    need.id.to_inner()
}

public(package) fun get_meal_need_id(need: &mut MealNeed): ID {
    need.id.to_inner()
}
