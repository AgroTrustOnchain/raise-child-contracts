module raise_child::child;

use raise_child::manage::{add_child_to_manage, Manage};
use std::string::String;
use sui::clock::{Self, Clock};
use sui::dynamic_field::{Self as df, Self};
use sui::event::emit;

const EFieldExisted: u64 = 1;
const EFieldNotExisted: u64 = 2;

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
    dynamic_fields: vector<String>,
    uploaded_at: u64,
    updated_at: u64,
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
        dynamic_fields: vector[],
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
