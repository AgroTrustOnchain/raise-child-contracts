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

// Thêm 1 struct liên kết với sự hỗ trợ từ nhà tự thiện
// Có thêm thông tin tần suất cập nhật hình ảnh

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
    let cur_time = clock::timestamp_ms(clock);

    let mut child = Child {
        id: object::new(ctx),
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
        books_needs: vector[init_books_need(1, year, ctx), init_books_need(2, year, ctx)],
        meal_need: init_meal_need(year, ctx),
        special_need_proposals: vector[],
        special_need_campaigns: vector[],
        uploaded_by: ctx.sender(),
        uploaded_at: cur_time,
        updated_at: cur_time,
    };
    let id = child.id.to_inner();

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
    need: &mut BooksNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    child: &mut Child,
    donor: &mut DonorNFT,
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
    assert!(child.region == get_local_pool_region(local_pool), EChildNotMatchedRegion);

    let (found, _) = vector::index_of(&mut child.books_needs, &get_books_need_id(need));
    assert!(found, ENeedNotExist);
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
    need: &mut MealNeed,
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    child: &mut Child,
    donor: &mut DonorNFT,
    months: u64,
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
    assert!(child.region == get_local_pool_region(local_pool), EChildNotMatchedRegion);

    let (found, _) = vector::index_of(&mut child.books_needs, &get_meal_need_id(need));
    assert!(found, ENeedNotExist);
    support_meal_need(
        need,
        manage,
        pool,
        local_pool,
        donor,
        months,
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
    child: &mut Child,
    manage: &mut Manage,
    pool: &mut LocalPool,
    target: u128,
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
    proposal: &mut SpecialNeedProposal,
    dao: &mut SpecialNeedDao,
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
    campaign: &mut SpecialNeedCampaign,
    manage: &mut Manage,
    child: &mut Child,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    donor: &mut DonorNFT,
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
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    _: &AdminCap,
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
    campaign: &mut SpecialNeedCampaign,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    child: &mut Child,
    withdraw_amount: u128,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(
        &mut child.special_need_campaigns,
        &get_special_need_campaign_id(campaign),
    );
    assert!(found && get_local_pool_region(local_pool) == child.region, ECampaignNotOfChild);
    assert!(is_admin_added(manage, ctx) || is_leader_in_pool(local_pool, ctx), ENotAuthorized);

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
    need: &mut BooksNeed,
    child: &mut Child,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(
        &mut child.books_needs,
        &get_books_need_id(need),
    );
    assert!(found && get_local_pool_region(local_pool) == child.region, ENeedNotExist);
    assert!(is_admin_added(manage, ctx) || is_leader_in_pool(local_pool, ctx), ENotAuthorized);
    create_books_need_withdraw_proposal(need, pool, local_pool, description, closed_at, clock, ctx);
}

public fun withdraw_from_books_need_proposal(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    _: &AdminCap,
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
    need: &mut MealNeed,
    child: &mut Child,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(
        &mut child.books_needs,
        &get_meal_need_id(need),
    );
    assert!(found && get_local_pool_region(local_pool) == child.region, ENeedNotExist);
    assert!(is_admin_added(manage, ctx) || is_leader_in_pool(local_pool, ctx), ENotAuthorized);
    create_meal_need_withdraw_proposal(need, pool, local_pool, description, closed_at, clock, ctx);
}

public fun withdraw_from_meal_need_proposal(
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    _: &AdminCap,
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

public(package) fun add_gift(child: &mut Child, id: ID) {
    vector::push_back(&mut child.gifts, id);
}

public(package) fun get_child_inner_id(child: &Child): ID {
    child.id.to_inner()
}

public(package) fun get_child_region(child: &Child): String {
    child.region
}
