module raise_child::child;

use raise_child::donor::DonorNFT;
use raise_child::manage::{
    add_child_to_manage,
    add_children_center_to_manage,
    is_create_children_center_requestor_valid,
    is_admin_added,
    RegisterLocalLeaderCap,
    UploadCenterCap,
    Manage,
    AdminCap
};
use raise_child::need::{
    BooksNeed,
    MealNeed,
    SpecialNeedProposal,
    SpecialNeedCampaign,
    SpecialNeedDao,
    init_books_need,
    init_meal_need,
    confirm_provide_meal,
    get_books_need_id,
    get_meal_need_id,
    support_books_need,
    support_meal_need,
    create_special_need_proposal,
    get_special_need_proposal_creator,
    get_special_need_proposal_id,
    create_special_need_campaign,
    support_special_need_campaign,
    withdraw_from_campaign,
    get_special_need_campaign_id,
    create_withdraw_proposal,
    create_books_need_withdraw_proposal,
    withdraw_from_books_need,
    create_meal_need_withdraw_proposal,
    withdraw_from_meal_need
};
use raise_child::pool::{
    VndPool,
    LocalPool,
    WithDrawProposal,
    PoolWithdrawDao,
    create_local_pool,
    get_local_pool_region,
    is_leader_in_pool,
    is_withdraw_proposal_matched_local_pool
};
use raise_child::staff::{StaffNFT, get_staff_region};
use std::ascii::index_of;
use std::string::String;
use sui::clock::{Self, Clock};
use sui::dynamic_field::{Self as df, Self};
use sui::event::emit;

const EFieldExisted: u64 = 1;
const EFieldNotExisted: u64 = 2;
const ECenterMissingInfo: u64 = 3;
const EInvalidAddCenter: u64 = 4;
const EChildNotMatchedRegion: u64 = 5;
const ENeedNotExist: u64 = 6;
const ENotAuthorized: u64 = 7;
const EProposalNotOfChild: u64 = 8;
const EWithdrawProposalNotOfCampaign: u64 = 9;
const ECampaignNotOfChild: u64 = 10;

public struct Child has key {
    id: UID,
    identity_code: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    region: String,
    avatar_blob_id: String,
    image_blob_ids: vector<String>,
    upload_image_periods: vector<u64>,
    upload_image_time: vector<String>,
    dynamic_fields: vector<String>,
    books_needs: vector<ID>,
    meal_need: ID,
    special_need_proposals: vector<ID>,
    special_need_campaigns: vector<ID>,
    gifts: vector<ID>,
    uploaded_by: address,
    uploaded_at: u64,
    updated_at: u64,
}

public struct ChildrenCenter has key {
    id: UID,
    region: String,
    center_address: String,
    center_phone_number: String,
    image_blob_ids: vector<String>,
    gifts: vector<ID>,
    all_gifts: vector<ID>,
    uploaded_at: u64,
    updated_at: u64,
}

public fun create_children_center(
    manage: &mut Manage,
    pool: &mut VndPool,
    cap: UploadCenterCap,
    region: String,
    center_address: String,
    center_phone_number: String,
    image_blob_id: String,
    leaders: vector<address>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let empty = b"".to_string();
    assert!(
        region != empty && center_address != empty && image_blob_id != empty && center_phone_number != empty,
        ECenterMissingInfo,
    );

    assert!(is_create_children_center_requestor_valid(manage, region, ctx), EInvalidAddCenter);

    let cur_time = clock::timestamp_ms(clock);
    let center = ChildrenCenter {
        id: object::new(ctx),
        region: region,
        center_address: center_address,
        center_phone_number: center_phone_number,
        image_blob_ids: vector[image_blob_id],
        gifts: vector[],
        all_gifts: vector[],
        uploaded_at: cur_time,
        updated_at: cur_time,
    };

    add_children_center_to_manage(manage, cap, region, center.id.to_inner(), ctx);
    create_local_pool(pool, region, leaders, ctx);
    transfer::share_object(center);
}

public fun upload_center_image(
    manage: &mut Manage,
    center: &mut ChildrenCenter,
    image_blob_id: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    if (is_create_children_center_requestor_valid(manage, center.region, ctx)) {
        if (image_blob_id != b"".to_string()) {
            vector::push_back(&mut center.image_blob_ids, image_blob_id);
            center.updated_at = clock::timestamp_ms(clock);
        }
    }
}

public fun upload_center_address(
    manage: &mut Manage,
    center: &mut ChildrenCenter,
    center_address: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    if (is_create_children_center_requestor_valid(manage, center.region, ctx)) {
        if (center_address != b"".to_string()) {
            center.center_address = center_address;
            center.updated_at = clock::timestamp_ms(clock);
        }
    }
}

public fun upload_center_phone_number(
    manage: &mut Manage,
    center: &mut ChildrenCenter,
    center_phone_number: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    if (is_create_children_center_requestor_valid(manage, center.region, ctx)) {
        if (center_phone_number != b"".to_string()) {
            center.center_phone_number = center_phone_number;
            center.updated_at = clock::timestamp_ms(clock);
        }
    }
}

public fun add_child(
    manage: &mut Manage,
    center: &mut ChildrenCenter,
    identity_code: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    region: String,
    avatar_blob_id: String,
    year: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(center.region == region, EChildNotMatchedRegion);
    let cur_time = clock::timestamp_ms(clock);

    let uid = object::new(ctx);
    let id = uid.to_inner();
    let mut child = Child {
        id: uid,
        identity_code: identity_code,
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        date_of_birth: date_of_birth,
        region: region,
        avatar_blob_id: avatar_blob_id,
        image_blob_ids: vector[],
        upload_image_periods: vector[],
        upload_image_time: vector[],
        dynamic_fields: vector[],
        gifts: vector[],
        books_needs: vector[init_books_need(1, year, id, ctx), init_books_need(2, year, id, ctx)],
        meal_need: init_meal_need(year, id, ctx),
        special_need_proposals: vector[],
        special_need_campaigns: vector[],
        uploaded_by: ctx.sender(),
        uploaded_at: cur_time,
        updated_at: cur_time,
    };

    transfer::share_object(child);
    add_child_to_manage(manage, id, ctx);
}

public fun add_string_metadata(
    child: &mut Child,
    key: String,
    value: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(&mut child.dynamic_fields, &key);
    assert!(!found, EFieldExisted);

    let cur_time = clock::timestamp_ms(clock);
    df::add(&mut child.id, key, value);
    vector::push_back(&mut child.dynamic_fields, key);
    child.updated_at = cur_time;
}

public fun add_u64_metadata(
    child: &mut Child,
    key: String,
    value: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(&mut child.dynamic_fields, &key);
    assert!(!found, EFieldExisted);

    let cur_time = clock::timestamp_ms(clock);
    df::add(&mut child.id, key, value);
    vector::push_back(&mut child.dynamic_fields, key);
    child.updated_at = cur_time;
}

public fun update_string_metadata(
    child: &mut Child,
    key: String,
    value: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(&mut child.dynamic_fields, &key);
    assert!(found, EFieldNotExisted);

    let cur_time = clock::timestamp_ms(clock);
    let value_mut = df::borrow_mut<String, String>(&mut child.id, key);
    *value_mut = value;
    child.updated_at = cur_time;
}

public fun update_u64_metadata(
    child: &mut Child,
    key: String,
    value: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(&mut child.dynamic_fields, &key);
    assert!(found, EFieldNotExisted);

    let cur_time = clock::timestamp_ms(clock);
    let value_mut = df::borrow_mut<String, u64>(&mut child.id, key);
    *value_mut = value;
    child.updated_at = cur_time;
}

public fun remove_string_metadata(
    child: &mut Child,
    key: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, idx) = vector::index_of(&mut child.dynamic_fields, &key);
    assert!(found, EFieldNotExisted);

    df::remove<String, String>(&mut child.id, key);
    let cur_time = clock::timestamp_ms(clock);
    vector::remove(&mut child.dynamic_fields, idx);
    child.updated_at = cur_time;
}

public fun remove_u64_metadata(child: &mut Child, key: String, clock: &Clock, ctx: &mut TxContext) {
    let (found, idx) = vector::index_of(&mut child.dynamic_fields, &key);
    assert!(found, EFieldNotExisted);

    df::remove<String, u64>(&mut child.id, key);
    let cur_time = clock::timestamp_ms(clock);
    vector::remove(&mut child.dynamic_fields, idx);
    child.updated_at = cur_time;
}

public fun support_child_books_need(
    manage: &mut Manage,
    pool: &mut VndPool,
    need: &mut BooksNeed,
    local_pool: &mut LocalPool,
    child: &mut Child,
    donor: &mut DonorNFT,
    amount: u64,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    validate_child_need(child, local_pool, false, get_books_need_id(need));
    support_books_need(
        need,
        manage,
        pool,
        local_pool,
        donor,
        amount,
        first_name,
        last_name,
        gender,
        phone_number,
        email,
        message,
        clock,
        ctx,
    );
}

public fun support_child_meal_need(
    manage: &mut Manage,
    pool: &mut VndPool,
    need: &mut MealNeed,
    local_pool: &mut LocalPool,
    child: &mut Child,
    donor: &mut DonorNFT,
    amount: u64,
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
    validate_child_need(child, local_pool, true, get_meal_need_id(need));
    support_meal_need(
        need,
        manage,
        pool,
        local_pool,
        donor,
        amount,
        start_period,
        end_period,
        first_name,
        last_name,
        gender,
        phone_number,
        email,
        message,
        clock,
        ctx,
    );
}

public fun create_child_special_need_proposal(
    manage: &mut Manage,
    child: &mut Child,
    pool: &mut LocalPool,
    target: u64,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    if (!is_admin_added(manage, ctx)) {
        assert!(
            is_leader_in_pool(pool, ctx) && get_local_pool_region(pool) == child.region,
            ENotAuthorized,
        );
    };

    vector::push_back(
        &mut child.special_need_proposals,
        create_special_need_proposal(
            child.id.to_inner(),
            target,
            description,
            closed_at,
            clock,
            ctx,
        ),
    );
}

public fun confirm_child_special_need_proposal(
    dao: &mut SpecialNeedDao,
    proposal: &mut SpecialNeedProposal,
    child: &mut Child,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(get_special_need_proposal_creator(proposal) == ctx.sender(), ENotAuthorized);

    let (found, _) = vector::index_of(
        &mut child.special_need_proposals,
        &get_special_need_proposal_id(proposal),
    );
    assert!(found, EProposalNotOfChild);
    vector::push_back(
        &mut child.special_need_campaigns,
        create_special_need_campaign(proposal, dao, clock, ctx),
    );
}

public fun support_child_special_need_campaign(
    manage: &mut Manage,
    pool: &mut VndPool,
    campaign: &mut SpecialNeedCampaign,
    child: &mut Child,
    local_pool: &mut LocalPool,
    donor: &mut DonorNFT,
    amount: u64,
    first_name: String,
    last_name: String,
    gender: String,
    phone_number: String,
    email: String,
    message: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(get_local_pool_region(local_pool) == child.region, EChildNotMatchedRegion);
    support_special_need_campaign(
        campaign,
        manage,
        pool,
        local_pool,
        donor,
        amount,
        first_name,
        last_name,
        gender,
        phone_number,
        email,
        message,
        clock,
        ctx,
    );
}

public fun withdraw_from_special_need_campaign(
    _: &AdminCap,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    campaign: &mut SpecialNeedCampaign,
    proposal: &mut WithDrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_withdraw_proposal_matched_local_pool(proposal, local_pool),
        EWithdrawProposalNotOfCampaign,
    );
    withdraw_from_campaign(pool, local_pool, campaign, proposal, dao, clock, ctx);
}

public fun create_special_need_withdraw_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    campaign: &mut SpecialNeedCampaign,
    child: &mut Child,
    withdraw_amount: u64,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    validate_child_need_pre_proposal(
        child,
        manage,
        get_special_need_campaign_id(campaign),
        local_pool,
        b"special".to_string(),
        ctx,
    );
    create_withdraw_proposal(
        campaign,
        pool,
        local_pool,
        withdraw_amount,
        description,
        closed_at,
        clock,
        ctx,
    );
}

public fun create_child_books_need_withdraw_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut BooksNeed,
    child: &mut Child,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    validate_child_need_pre_proposal(
        child,
        manage,
        get_books_need_id(need),
        local_pool,
        b"books".to_string(),
        ctx,
    );
    create_books_need_withdraw_proposal(need, pool, local_pool, description, closed_at, clock, ctx);
}

public fun withdraw_from_books_need_proposal(
    _: &AdminCap,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut BooksNeed,
    proposal: &mut WithDrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_withdraw_proposal_matched_local_pool(proposal, local_pool),
        EWithdrawProposalNotOfCampaign,
    );
    withdraw_from_books_need(pool, local_pool, need, proposal, dao, clock, ctx);
}

public fun create_child_meal_need_withdraw_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut MealNeed,
    child: &mut Child,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    validate_child_need_pre_proposal(
        child,
        manage,
        get_meal_need_id(need),
        local_pool,
        b"meal".to_string(),
        ctx,
    );
    create_meal_need_withdraw_proposal(need, pool, local_pool, description, closed_at, clock, ctx);
}

public fun withdraw_from_meal_need_proposal(
    _: &AdminCap,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut MealNeed,
    proposal: &mut WithDrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_withdraw_proposal_matched_local_pool(proposal, local_pool),
        EWithdrawProposalNotOfCampaign,
    );
    withdraw_from_meal_need(pool, local_pool, need, proposal, dao, clock, ctx);
}

public fun confirm_provide_meal_for_child(
    child: &mut Child,
    need: &mut MealNeed,
    staff: &StaffNFT,
    image_blob_id: String,
    provide_date: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(get_staff_region(staff) == child.region, ENotAuthorized);
    assert!(child.meal_need == get_meal_need_id(need), ENeedNotExist);

    let cur_time = clock::timestamp_ms(clock);
    confirm_provide_meal(need, image_blob_id, provide_date, cur_time, ctx);
    child.updated_at = cur_time;
}

public(package) fun add_gift_to_child(child: &mut Child, center: &mut ChildrenCenter, id: ID) {
    vector::push_back(&mut child.gifts, id);
    vector::push_back(&mut center.all_gifts, id);
}

public(package) fun add_gift_to_center(center: &mut ChildrenCenter, id: ID) {
    vector::push_back(&mut center.gifts, id);
    vector::push_back(&mut center.all_gifts, id);
}

public(package) fun get_child_inner_id(child: &Child): ID {
    child.id.to_inner()
}

public(package) fun get_center_inner_id(center: &ChildrenCenter): ID {
    center.id.to_inner()
}

public(package) fun get_child_region(child: &Child): String {
    child.region
}

public(package) fun get_center_region(center: &ChildrenCenter): String {
    center.region
}

public(package) fun is_child_of_center(child: &Child, center: &ChildrenCenter): bool {
    child.region == center.region
}

fun validate_child_need(
    child: &mut Child,
    local_pool: &mut LocalPool,
    is_meal_need: bool,
    need_id: ID,
) {
    assert!(child.region == get_local_pool_region(local_pool), EChildNotMatchedRegion);
    let found = if (!is_meal_need) {
        let (need_found, _) = vector::index_of(&mut child.books_needs, &need_id);
        need_found
    } else {
        child.meal_need == need_id
    };

    assert!(found, ENeedNotExist);
}

fun validate_child_need_pre_proposal(
    child: &mut Child,
    manage: &mut Manage,
    need_id: ID,
    local_pool: &mut LocalPool,
    need_type: String,
    ctx: &mut TxContext,
) {
    let found = if (need_type == b"meal".to_string()) {
        child.meal_need == need_id
    } else if (need_type == b"bookS".to_string()) {
        let (need_found, _) = vector::index_of(&child.books_needs, &need_id);
        need_found
    } else if (need_type == b"special".to_string()) {
        let (need_found, _) = vector::index_of(&child.special_need_campaigns, &need_id);
        need_found
    } else {
        false
    };

    assert!(found && get_local_pool_region(local_pool) == child.region, ENeedNotExist);
    assert!(is_admin_added(manage, ctx) || is_leader_in_pool(local_pool, ctx), ENotAuthorized);
}
