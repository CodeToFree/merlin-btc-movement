module merlin_btc::merlin_btc {

    use std::option;
    use std::vector;
    use std::signer;
    use std::object::{Self, Object, ExtendRef};
    use std::fungible_asset::{Self, BurnRef, Metadata, MintRef};
    use std::primary_fungible_store;
    use std::string::utf8;

    const ASSET_SYMBOL: vector<u8> = b"MBTC";
    const ASSET_NAME: vector<u8> = b"Merlin BTC";
    const ASSET_DECIMALS: u8 = 8;
    const CONTRACT_ADDRESS: address = @merlin_btc;

    const ENOT_OWNER: u64 = 101;
    const ENOT_WHITELISTED: u64 = 102;

    struct Storage has key, store {
        store_contract_signer_extend_ref: ExtendRef,
        owner: address,
        whitelist: vector<address>,
        mint_ref: MintRef,
        burn_ref: BurnRef,
    }

    fun init_module(admin: &signer) {
        let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
        let extend_ref = object::generate_extend_ref(constructor_ref);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(ASSET_NAME), /* name */
            utf8(ASSET_SYMBOL), /* symbol */
            ASSET_DECIMALS, /* decimals */
            utf8(b""), /* icon */
            utf8(b""), /* project */
        );
        let metadata_object_signer = object::generate_signer(constructor_ref);
        let cap_store = Storage {
            store_contract_signer_extend_ref: extend_ref,
            owner: signer::address_of(admin),
            whitelist: vector::empty(),
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
        };
        move_to(&metadata_object_signer, cap_store);
    }

    #[view]
    public fun get_fa_address(): address {
        object::create_object_address(&CONTRACT_ADDRESS, ASSET_SYMBOL)
    }

    #[view]
    public fun get_owner(): address acquires Storage {
        let store = borrow_global<Storage>(get_fa_address());
        store.owner
    }

    #[view]
    public fun get_fa_metadata(): Object<Metadata> {
        object::address_to_object<Metadata>(get_fa_address())
    }

    #[view]
    public fun check_whitelist(account: address): bool acquires Storage {
        let store = borrow_global<Storage>(get_fa_address());
        vector::contains(&store.whitelist, &account)
    }

    fun get_store_contract_signer(): signer acquires Storage {
        let store = borrow_global<Storage>(get_fa_address());
        object::generate_signer_for_extending(&store.store_contract_signer_extend_ref)
    }

    public entry fun transfer_ownership(
        account: &signer,
        new_owner: address
    ) acquires Storage {
        let store_mut = borrow_global_mut<Storage>(get_fa_address());
        assert!(signer::address_of(account) == store_mut.owner, ENOT_OWNER);
        store_mut.owner = new_owner;
    }

    public entry fun add_to_whitelist(
        account: &signer,
        whitelist_address: address
    ) acquires Storage {
        let store_mut = borrow_global_mut<Storage>(get_fa_address());
        assert!(signer::address_of(account) == store_mut.owner, ENOT_OWNER);
        vector::push_back(&mut store_mut.whitelist, whitelist_address);
    }

    public entry fun remove_from_whitelist(
        account: &signer,
        whitelist_address: address
    ) acquires Storage {
        let store_mut = borrow_global_mut<Storage>(get_fa_address());
        assert!(signer::address_of(account) == store_mut.owner, ENOT_OWNER);
        vector::remove_value(&mut store_mut.whitelist, &whitelist_address);
    }

    public entry fun mint(
        account: &signer,
        to: address,
        amount: u64
    ) acquires Storage {
        assert!(check_whitelist(signer::address_of(account)), ENOT_WHITELISTED);
        let store = borrow_global<Storage>(get_fa_address());
        primary_fungible_store::mint(&store.mint_ref, to, amount);
    }

    public entry fun burn(
        account: &signer,
        owner: address,
        amount: u64
    ) acquires Storage {
        assert!(check_whitelist(signer::address_of(account)), ENOT_WHITELISTED);
        let store = borrow_global<Storage>(get_fa_address());
        primary_fungible_store::burn(&store.burn_ref, owner, amount);
    }

}
