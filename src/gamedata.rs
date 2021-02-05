use postgres::{Client, NoTls};
use postgres::types::Type as pgT;
use postgres::types::ToSql;
use postgres::row::Row;
use std::collections::HashMap;
use std::marker::Sync;
use serde_json::{Value, Number};
use time::OffsetDateTime;

struct GameColumn {
    name: &'static str,
    f_type: pgT,
    nullable: bool
}

const GAME_COLUMNS: [GameColumn; 21] = [
    GameColumn { name: "server", f_type: pgT::VARCHAR, nullable: false},
    GameColumn { name: "variant", f_type: pgT::VARCHAR, nullable: false},
    GameColumn { name: "version", f_type: pgT::VARCHAR, nullable: false},
    GameColumn { name: "name", f_type: pgT::VARCHAR, nullable: false},
    GameColumn { name: "role", f_type: pgT::VARCHAR, nullable: false},
    GameColumn { name: "race", f_type: pgT::VARCHAR, nullable: false},
    GameColumn { name: "gender", f_type: pgT::VARCHAR, nullable: false},
    GameColumn { name: "align", f_type: pgT::VARCHAR, nullable: false},
    GameColumn { name: "points", f_type: pgT::INT8, nullable: false},
    GameColumn { name: "dumplog", f_type: pgT::VARCHAR, nullable: true},
    GameColumn { name: "turns", f_type: pgT::INT8, nullable: false},
    GameColumn { name: "realtime", f_type: pgT::INT8, nullable: true},
    GameColumn { name: "starttime_raw", f_type: pgT::INT8, nullable: true},
    GameColumn { name: "endtime_raw", f_type: pgT::INT8, nullable: true},
    GameColumn { name: "endtime", f_type: pgT::TIMESTAMPTZ, nullable: false},
    GameColumn { name: "deathlev", f_type: pgT::INT4, nullable: false},
    GameColumn { name: "maxlvl", f_type: pgT::INT4, nullable: false},
    GameColumn { name: "hp", f_type: pgT::INT4, nullable: false},
    GameColumn { name: "maxhp", f_type: pgT::INT4, nullable: false},
    GameColumn { name: "conducts", f_type: pgT::VARCHAR_ARRAY, nullable: true},
    GameColumn { name: "death", f_type: pgT::VARCHAR, nullable: false}
];

fn compose_str_array(array: Vec<String>) -> Vec<Value> {
    array.into_iter().map(|str| { Value::String(str) }).collect()
}

fn compose_field(row: &Row, column: &GameColumn) -> Value {
    let result = match column.f_type {
        pgT::VARCHAR => {
            match row.get::<&str, Option<String>>(column.name) {
                Some(string) => Value::String(string),
                None => Value::Null
            }
        },
        pgT::VARCHAR_ARRAY => {
            match row.get::<&str, Option<Vec<String>>>(column.name) {
                Some(array) => Value::Array(compose_str_array(array)),
                None => Value::Null
            }
        },
        pgT::INT8 => {
            match row.get::<&str, Option<i64>>(column.name) {
                Some(number) => Value::Number(Number::from(number)),
                None => Value::Null
            }
        },
        pgT::INT4 => {
            match row.get::<&str, Option<i64>>(column.name) {
                Some(number) => Value::Number(Number::from(number)),
                None => Value::Null
            }
        },
        pgT::TIMESTAMPTZ => {
            match row.get::<&str, Option<OffsetDateTime>>(column.name) {
                Some(timestamp) => Value::String(timestamp.to_string()),
                None => Value::Null
            }
        }
        _ => panic!("unhandled type")
    };
    if column.nullable {
       result 
    } else {
        match result {
            Value::Null => panic!("got null on non-nullable type {}", column.f_type),
            _ => result
        }
    }
}

pub fn get_games_as_json(query: &str, params: &[&(dyn ToSql + Sync)]) -> Result<String, postgres::error::Error> {
    let mut client = Client::connect("host=localhost user=nhdbstats password=xxx dbname=nhdb", NoTls)?;
    let mut records = Vec::new();
    for row in client.query(query, params)? {
        let mut record = HashMap::new();
        for column in GAME_COLUMNS.iter() {
            record.insert(column.name, compose_field(&row, &column));
        }
        records.push(record)
    }
    Ok(serde_json::to_string(&records).unwrap())
}