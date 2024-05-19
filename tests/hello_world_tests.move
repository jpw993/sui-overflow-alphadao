#[test_only]
module alpha_dao::hello_world_tests {
    use alpha_dao::hello_world;

    #[test]
    fun test_hello_world() {
        assert!(hello_world::hello_world() == b"Hello, World!".to_string(), 0);
    }
}
