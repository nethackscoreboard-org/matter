mod gamedata;
use gamedata::get_games_as_json;
use actix_web::{get, App, HttpResponse, HttpServer, Responder};

#[get("/")]
async fn hello() -> impl Responder {
    HttpResponse::Ok().body("Hello world!")
}

#[get("/ascended")]
async fn ascended() -> impl Responder {
    let result = get_games_as_json("
        SELECT *
        FROM
        v_ascended
        WHERE variant='nh'
        LIMIT 100
    ", &[]).unwrap();
    HttpResponse::Ok().body(result)
}

#[get("/realtime")]
async fn realtime() -> impl Responder {
    let result = get_games_as_json("
        SELECT *
        FROM
        (
            SELECT DISTINCT ON (name) * FROM v_ascended
            WHERE variant='nh' AND realtime > 0
            ORDER BY name, realtime ASC
        ) t
        ORDER BY realtime ASC LIMIT 100
    ", &[]).unwrap();
    HttpResponse::Ok().body(result)
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