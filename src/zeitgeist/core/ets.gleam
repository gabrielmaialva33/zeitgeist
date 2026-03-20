import gleam/dynamic.{type Dynamic}

pub type EtsTable

pub fn new(name: String, table_type: String) -> Result(EtsTable, String) {
  new_table_ffi(name, table_type)
}

pub fn insert(table: EtsTable, key: String, value: a) -> Nil {
  insert_ffi(table, key, value)
}

pub fn lookup(table: EtsTable, key: String) -> Result(Dynamic, Nil) {
  lookup_ffi(table, key)
}

pub fn lookup_all(table: EtsTable) -> List(Dynamic) {
  lookup_all_ffi(table)
}

pub fn delete_key(table: EtsTable, key: String) -> Nil {
  delete_key_ffi(table, key)
}

pub fn delete_table(table: EtsTable) -> Nil {
  delete_table_ffi(table)
}

pub fn size(table: EtsTable) -> Int {
  table_size_ffi(table)
}

pub fn save(table: EtsTable, path: String) -> Result(Nil, String) {
  tab_to_file_ffi(table, path)
}

pub fn restore(path: String) -> Result(EtsTable, String) {
  file_to_tab_ffi(path)
}

@external(erlang, "zeitgeist_ets_ffi", "new_table")
fn new_table_ffi(name: String, table_type: String) -> Result(EtsTable, String)

@external(erlang, "zeitgeist_ets_ffi", "insert")
fn insert_ffi(table: EtsTable, key: String, value: a) -> Nil

@external(erlang, "zeitgeist_ets_ffi", "lookup")
fn lookup_ffi(table: EtsTable, key: String) -> Result(Dynamic, Nil)

@external(erlang, "zeitgeist_ets_ffi", "lookup_all")
fn lookup_all_ffi(table: EtsTable) -> List(Dynamic)

@external(erlang, "zeitgeist_ets_ffi", "delete_key")
fn delete_key_ffi(table: EtsTable, key: String) -> Nil

@external(erlang, "zeitgeist_ets_ffi", "delete_table")
fn delete_table_ffi(table: EtsTable) -> Nil

@external(erlang, "zeitgeist_ets_ffi", "table_size")
fn table_size_ffi(table: EtsTable) -> Int

@external(erlang, "zeitgeist_ets_ffi", "tab_to_file")
fn tab_to_file_ffi(table: EtsTable, path: String) -> Result(Nil, String)

@external(erlang, "zeitgeist_ets_ffi", "file_to_tab")
fn file_to_tab_ffi(path: String) -> Result(EtsTable, String)
