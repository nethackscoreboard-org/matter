use actix_web::{get, App, HttpResponse, HttpServer, Responder};
use postgres::{Client, NoTls};
use std::collections::HashMap;
use serde_json::{Value, Number};

#[get("/")]
async fn hello() -> impl Responder {
    HttpResponse::Ok().body("Hello world!")
}

#[get("/ascended")]
async fn ascended() -> impl Responder {
    let mut client = Client::connect("host=localhost user=nhdbstats password=xxx dbname=nhdb", NoTls).unwrap();
    let mut records = Vec::new();
    for row in client.query("
        SELECT *
        FROM
        v_ascended
        WHERE variant='nh'
        LIMIT 100
    ", &[]).unwrap() {
        let mut record = HashMap::new();
        for k in ["server", "variant", "version", "name", "race", "role", "gender", "align"].iter() {
            record.insert(k, Value::String(row.get(k)));
        }
        for k in ["points", "turns", "realtime", "starttime_raw", "endtime_raw"].iter() {
            record.insert(k, Value::Number(Number::from(row.get::<&str, i64>(k))));
        }
        for k in ["hp", "maxhp", "deathlev", "maxlvl"].iter() {
            record.insert(k, Value::Number(Number::from(row.get::<&str, i32>(k))));
        }
        records.push(record);
    }
    HttpResponse::Ok().body(serde_json::to_string(&records).unwrap())
}

#[get("/realtime")]
async fn realtime() -> impl Responder {
    let mut client = Client::connect("host=localhost user=nhdbstats password=xxx dbname=nhdb", NoTls).unwrap();
    let mut records = Vec::new();
    for row in client.query("
        SELECT *
        FROM
        (
            SELECT DISTINCT ON (name) * FROM v_ascended
            WHERE variant='nh' AND realtime > 0
            ORDER BY name, realtime ASC
        ) t
        ORDER BY realtime ASC LIMIT 100
    ", &[]).unwrap() {
        let mut record = HashMap::new();
        for k in ["server", "variant", "version", "name", "race", "role", "gender", "align"].iter() {
            record.insert(k, Value::String(row.get(k)));
        }
        // this will panic if any of these are NULL
        for k in ["points", "turns", "realtime", "starttime_raw", "endtime_raw"].iter() {
            record.insert(k, Value::Number(Number::from(row.get::<&str, i64>(k))));
        }
        for k in ["hp", "maxhp", "deathlev", "maxlvl"].iter() {
            record.insert(k, Value::Number(Number::from(row.get::<&str, i32>(k))));
        }
        records.push(record);
    }
    HttpResponse::Ok().body(serde_json::to_string(&records).unwrap())
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| {
        App::new()
            .service(hello)
            .service(realtime)
            .service(ascended)
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await
}