----------------------------------------------------------------------------
--- views
----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_sources AS
  SELECT
    logfiles_i, server, variant, descr, logurl, localfile, fpos, static,
    lines,
    to_char(lastchk, 'YYYY-MM-DD HH24:MI') AS lastchk_trunc,
    current_timestamp - lastchk < interval '1 hour' AS lastchk_1h,
    current_timestamp - lastchk < interval '1 day' AS lastchk_1d,
    current_timestamp - lastchk < interval '30 days' AS lastchk_30d,
    to_char(max(endtime), 'YYYY-MM-DD HH24:MI') AS lastentry_trunc,
    current_timestamp - max(endtime) < interval '1 hour' AS lastentry_1h,
    current_timestamp - max(endtime) < interval '1 day' AS lastentry_1d,
    current_timestamp - max(endtime) < interval '30 days' AS lastentry_30d,
    count(*) AS game_count
  FROM
    logfiles
    LEFT JOIN games USING ( logfiles_i )
  GROUP BY
    logfiles_i, server, variant, descr, logurl, localfile, fpos, static,
    lines
  ORDER BY
    logfiles_i;

GRANT SELECT ON v_sources TO nhdbstats;
