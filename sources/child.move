module raise_child::child;

use raise_child::donor::DonorNFT;
use raise_child::manage::{
    add_child_to_manage,
    add_children_center_to_manage,
    is_create_children_center_requestor_valid,
    is_admin_added,
    is_admin_added_v2,
    is_leader_added,
    UploadCenterCap,
    Manage
};
use raise_child::need::{
    BooksNeed,
    MealNeed,
    HealthInsuranceNeed,
    SpecialNeedProposal,
    SpecialNeedCampaign,
    SpecialNeedDao,
    init_books_need,
    init_meal_need,
    init_health_insurance_need,
    confirm_provide_meal,
    get_books_need_id,
    get_meal_need_id,
    support_books_need,
    support_meal_need,
    create_special_need_proposal,
    create_special_need_proposal_v2,
    get_special_need_proposal_creator,
    get_special_need_proposal_id,
    get_health_insurance_need_id,
    create_special_need_campaign,
    support_special_need_campaign,
    support_health_insurance_need,
    withdraw_from_campaign,
    get_special_need_campaign_id,
    create_withdraw_proposal,
    create_withdraw_proposal_v2,
    create_books_need_withdraw_proposal,
    create_books_need_withdraw_proposal_v2,
    withdraw_from_books_need,
    create_meal_need_withdraw_proposal,
    create_meal_need_withdraw_proposal_v2,
    create_health_insurance_need_withdraw_proposal,
    create_health_insurance_need_withdraw_proposal_v2,
    withdraw_from_meal_need,
    withdraw_from_health_insurance_need,
    confirm_provide_meal_v2,
    update_books_need,
    update_health_insurance_need,
    update_meal_need
};
use raise_child::pool::{
    VndPool,
    LocalPool,
    WithdrawProposal,
    PoolWithdrawDao,
    create_local_pool,
    get_local_pool_region,
    is_leader_in_pool,
    is_leader_in_pool_v2,
    is_withdraw_proposal_matched_local_pool,
    add_donation_amount_to_specific_need_in_pool
};
use raise_child::staff::{StaffNFT, get_staff_region, is_staff_matched_region, is_local_leader};
use raise_child::task::create_task_proof;
use std::string::String;
use sui::clock::{Self, Clock};
use sui::dynamic_field as df;

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
const EMissingChildProfileInfo: u64 = 11;

public struct Child has key {
    id: UID,
    identity_code: String,
    first_name: String,
    last_name: String,
    gender: String,
    date_of_birth: String,
    home_address: String,
    region: String,
    avatar_blob_id: String,
    home_blob_id: String,
    guardian_profiles: vector<ChildGuardianProfile>,
    image_blob_ids: vector<String>,
    upload_image_periods: vector<u64>,
    upload_image_time: vector<String>,
    dynamic_fields: vector<String>,
    books_needs: vector<ID>,
    meal_need: ID,
    health_insurance_need: ID,
    special_need_proposals: vector<ID>,
    special_need_campaigns: vector<ID>,
    gifts: vector<ID>,
    uploaded_by: address,
    uploaded_at: u64,
    updated_at: u64,
}

public struct ChildGuardianProfile has store {
    full_name: String,
    phone_number: String,
    relation: String,
    identity_card_blob_id: String,
}

public struct ChildrenCenter has key {
    id: UID,
    region: String,
    center_address: String,
    center_phone_number: String,
    child_ids: vector<ID>,
    image_blob_ids: vector<String>,
    gifts: vector<ID>,
    task_proofs: vector<ID>,
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
        child_ids: vector[],
        gifts: vector[],
        all_gifts: vector[],
        task_proofs: vector[],
        uploaded_at: cur_time,
        updated_at: cur_time,
    };

    add_children_center_to_manage(manage, cap, region, center.id.to_inner(), ctx);
    create_local_pool(pool, region, leaders, ctx);
    transfer::share_object(center);
}

public fun submit_task(
    center: &mut ChildrenCenter,
    staff: &StaffNFT,
    description: String,
    image_blob_id: String,
    actor: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_staff_matched_region(staff, center.region) && is_local_leader(staff),
        ENotAuthorized,
    );
    let proof_id = create_task_proof(description, image_blob_id, actor, clock, ctx);
    vector::push_back(&mut center.task_proofs, proof_id);
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
    home_address: String,
    region: String,
    avatar_blob_id: String,
    home_blob_id: String,
    first_guardian_full_name: String,
    first_guardian_phone_number: String,
    first_guardian_relation: String,
    first_guardian_identity_card_blob_id: String,
    second_guardian_full_name: String,
    second_guardian_phone_number: String,
    second_guardian_relation: String,
    second_guardian_identity_card_blob_id: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(center.region == region, EChildNotMatchedRegion);

    let empty = b"".to_string();
    assert!(
        identity_code != empty
            && first_name != empty
            && last_name != empty 
            && gender != empty
            && date_of_birth != empty
            && home_address != empty
            && avatar_blob_id != empty
            && home_blob_id != empty
            && first_guardian_full_name != empty
            && first_guardian_phone_number != empty
            && first_guardian_relation != empty
            && first_guardian_identity_card_blob_id != empty,
        EMissingChildProfileInfo,
    );

    let cur_time = clock::timestamp_ms(clock);
    let uid = object::new(ctx);
    let id = uid.to_inner();

    let mut guardian_profiles = vector[
        ChildGuardianProfile {
            full_name: first_guardian_full_name,
            phone_number: first_guardian_phone_number,
            relation: first_guardian_relation,
            identity_card_blob_id: first_guardian_identity_card_blob_id,
        },
    ];

    if (
        second_guardian_full_name != empty
        && second_guardian_phone_number != empty
        && second_guardian_relation != empty
        && second_guardian_identity_card_blob_id != empty
    ) {
        vector::push_back(
            &mut guardian_profiles,
            ChildGuardianProfile {
                full_name: second_guardian_full_name,
                phone_number: second_guardian_phone_number,
                relation: second_guardian_relation,
                identity_card_blob_id: second_guardian_identity_card_blob_id,
            },
        );
    };

    let child = Child {
        id: uid,
        identity_code: identity_code,
        first_name: first_name,
        last_name: last_name,
        gender: gender,
        date_of_birth: date_of_birth,
        home_address: home_address,
        region: region,
        avatar_blob_id: avatar_blob_id,
        home_blob_id: home_blob_id,
        guardian_profiles: guardian_profiles,
        image_blob_ids: vector[],
        upload_image_periods: vector[],
        upload_image_time: vector[],
        dynamic_fields: vector[],
        gifts: vector[],
        books_needs: vector[init_books_need(1, id, ctx), init_books_need(2, id, ctx)],
        meal_need: init_meal_need(id, ctx),
        health_insurance_need: init_health_insurance_need(id, ctx),
        special_need_proposals: vector[],
        special_need_campaigns: vector[],
        uploaded_by: ctx.sender(),
        uploaded_at: cur_time,
        updated_at: cur_time,
    };

    transfer::share_object(child);
    add_child_to_manage(manage, id, ctx);
    vector::push_back(&mut center.child_ids, id);
}

public fun add_string_metadata(
    child: &mut Child,
    key: String,
    value: String,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (found, _) = vector::index_of(&child.dynamic_fields, &key);
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
    let (found, _) = vector::index_of(&child.dynamic_fields, &key);
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
    let need_type = b"books".to_string();
    validate_child_need(child, local_pool, need_type, get_books_need_id(need));
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

    add_donation_amount_to_specific_need_in_pool(pool, local_pool, need_type, amount);
}

public fun support_child_health_insurance_need(
    manage: &mut Manage,
    pool: &mut VndPool,
    need: &mut HealthInsuranceNeed,
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
    let need_type = b"health".to_string();
    validate_child_need(
        child,
        local_pool,
        need_type,
        get_health_insurance_need_id(need),
    );
    support_health_insurance_need(
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

    add_donation_amount_to_specific_need_in_pool(pool, local_pool, need_type, amount);
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
    let need_type = b"meal".to_string();
    validate_child_need(child, local_pool, need_type, get_meal_need_id(need));
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

    add_donation_amount_to_specific_need_in_pool(pool, local_pool, need_type, amount);
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

public fun create_child_special_need_proposal_v2(
    manage: &mut Manage,
    child: &mut Child,
    pool: &mut LocalPool,
    target: u64,
    description: String,
    proof_blob_id: String,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // let sender = ctx.sender();

    // Sender must be admin
    // Reviewer and creator must be different
    // Pool region must match child region
    assert!(
        is_admin_added(manage, ctx) && ctx.sender() != creator && get_local_pool_region(pool) == child.region,
        ENotAuthorized,
    );

    // Creator can be admin or leader in pool
    assert!(
        is_leader_in_pool_v2(pool, creator) || is_admin_added_v2(manage, creator),
        ENotAuthorized,
    );

    vector::push_back(
        &mut child.special_need_proposals,
        create_special_need_proposal_v2(
            child.id.to_inner(),
            target,
            description,
            proof_blob_id,
            closed_at,
            creator,
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
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    campaign: &mut SpecialNeedCampaign,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_withdraw_proposal_matched_local_pool(proposal, local_pool),
        EWithdrawProposalNotOfCampaign,
    );
    assert!(is_admin_added(manage, ctx), ENotAuthorized);
    withdraw_from_campaign(manage, pool, local_pool, campaign, proposal, dao, clock, ctx);
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

public fun create_special_need_withdraw_proposal_v2(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    campaign: &mut SpecialNeedCampaign,
    child: &mut Child,
    withdraw_amount: u64,
    description: String,
    closed_at: u64,
    creator: address,
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
    create_withdraw_proposal_v2(
        manage,
        campaign,
        pool,
        local_pool,
        withdraw_amount,
        description,
        closed_at,
        creator,
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

public fun create_child_books_need_withdraw_proposal_v2(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut BooksNeed,
    child: &mut Child,
    description: String,
    proof_blob_id: String,
    closed_at: u64,
    creator: address,
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
    create_books_need_withdraw_proposal_v2(
        manage,
        need,
        pool,
        local_pool,
        description,
        proof_blob_id,
        closed_at,
        creator,
        clock,
        ctx,
    );
}

public fun withdraw_from_books_need_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut BooksNeed,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_withdraw_proposal_matched_local_pool(proposal, local_pool),
        EWithdrawProposalNotOfCampaign,
    );
    assert!(is_admin_added(manage, ctx), ENotAuthorized);
    withdraw_from_books_need(manage, pool, local_pool, need, proposal, dao, clock, ctx);
}

public fun withdraw_from_health_insurance_need_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut HealthInsuranceNeed,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_withdraw_proposal_matched_local_pool(proposal, local_pool),
        EWithdrawProposalNotOfCampaign,
    );
    assert!(is_admin_added(manage, ctx), ENotAuthorized);

    withdraw_from_health_insurance_need(manage, pool, local_pool, need, proposal, dao, clock, ctx);
}

public fun create_child_health_insurance_need_withdraw_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut HealthInsuranceNeed,
    child: &mut Child,
    description: String,
    closed_at: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    validate_child_need_pre_proposal(
        child,
        manage,
        get_health_insurance_need_id(need),
        local_pool,
        b"health".to_string(),
        ctx,
    );
    create_health_insurance_need_withdraw_proposal(
        need,
        pool,
        local_pool,
        description,
        closed_at,
        clock,
        ctx,
    );
}

public fun create_child_health_insurance_need_withdraw_proposal_v2(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut HealthInsuranceNeed,
    child: &mut Child,
    description: String,
    proof_blob_id: String,
    closed_at: u64,
    creator: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    validate_child_need_pre_proposal(
        child,
        manage,
        get_health_insurance_need_id(need),
        local_pool,
        b"health".to_string(),
        ctx,
    );
    create_health_insurance_need_withdraw_proposal_v2(
        manage,
        need,
        pool,
        local_pool,
        description,
        proof_blob_id,
        closed_at,
        creator,
        clock,
        ctx,
    );
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

public fun create_child_meal_need_withdraw_proposal_v2(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut MealNeed,
    child: &mut Child,
    description: String,
    proof_blob_id: String,
    closed_at: u64,
    creator: address,
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
    create_meal_need_withdraw_proposal_v2(
        manage,
        need,
        pool,
        local_pool,
        description,
        proof_blob_id,
        closed_at,
        creator,
        clock,
        ctx,
    );
}

public fun withdraw_from_meal_need_proposal(
    manage: &mut Manage,
    pool: &mut VndPool,
    local_pool: &mut LocalPool,
    need: &mut MealNeed,
    proposal: &mut WithdrawProposal,
    dao: &mut PoolWithdrawDao,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_withdraw_proposal_matched_local_pool(proposal, local_pool),
        EWithdrawProposalNotOfCampaign,
    );
    assert!(is_admin_added(manage, ctx), ENotAuthorized);

    withdraw_from_meal_need(manage, pool, local_pool, need, proposal, dao, clock, ctx);
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

public fun confirm_provide_meal_for_child_v2(
    child: &mut Child,
    need: &mut MealNeed,
    staff: &StaffNFT,
    image_blob_id: String,
    provide_date: String,
    actor: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(get_staff_region(staff) == child.region && is_local_leader(staff), ENotAuthorized);
    assert!(child.meal_need == get_meal_need_id(need), ENeedNotExist);

    let cur_time = clock::timestamp_ms(clock);
    confirm_provide_meal_v2(need, image_blob_id, provide_date, actor, cur_time);
    child.updated_at = cur_time;
}

public fun update_child_books_need(
    manage: &mut Manage,
    staff: &mut StaffNFT,
    child: &mut Child,
    need: &mut BooksNeed,
    year: u64,
    value: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_staff_matched_region(staff, child.region) && is_local_leader(staff) && is_leader_added(manage, ctx),
        ENotAuthorized,
    );
    let need_id = get_books_need_id(need);
    let (need_found, _) = vector::index_of(&child.books_needs, &need_id);
    assert!(need_found, ENeedNotExist);

    update_books_need(need, year, value);
    child.updated_at = clock::timestamp_ms(clock);
}

public fun update_child_meal_need(
    manage: &mut Manage,
    staff: &mut StaffNFT,
    child: &mut Child,
    need: &mut MealNeed,
    year: u64,
    value: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_staff_matched_region(staff, child.region) && is_local_leader(staff) && is_leader_added(manage, ctx),
        ENotAuthorized,
    );
    let need_id = get_meal_need_id(need);
    assert!(need_id == child.meal_need, ENeedNotExist);

    update_meal_need(need, year, value);
    child.updated_at = clock::timestamp_ms(clock);
}

public fun update_child_health_insurance_need(
    manage: &mut Manage,
    staff: &mut StaffNFT,
    child: &mut Child,
    need: &mut HealthInsuranceNeed,
    year: u64,
    value: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        is_staff_matched_region(staff, child.region) && is_local_leader(staff) && is_leader_added(manage, ctx),
        ENotAuthorized,
    );
    let need_id = get_health_insurance_need_id(need);
    assert!(need_id == child.health_insurance_need, ENeedNotExist);

    update_health_insurance_need(need, year, value);
    child.updated_at = clock::timestamp_ms(clock);
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
    need_type: String,
    need_id: ID,
) {
    assert!(child.region == get_local_pool_region(local_pool), EChildNotMatchedRegion);
    let found = if (need_type == b"books".to_string()) {
        let (need_found, _) = vector::index_of(&mut child.books_needs, &need_id);
        need_found
    } else if (need_type == b"meal".to_string()) {
        child.meal_need == need_id
    } else {
        child.health_insurance_need == need_id
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
    } else if (need_type == b"books".to_string()) {
        let (need_found, _) = vector::index_of(&child.books_needs, &need_id);
        need_found
    } else if (need_type == b"special".to_string()) {
        let (need_found, _) = vector::index_of(&child.special_need_campaigns, &need_id);
        need_found
    } else {
        child.health_insurance_need == need_id
    };

    assert!(found && get_local_pool_region(local_pool) == child.region, ENeedNotExist);
    assert!(is_admin_added(manage, ctx) || is_leader_in_pool(local_pool, ctx), ENotAuthorized);
}
