-module(erma_tests).

-include("erma.hrl").
-include_lib("eunit/include/eunit.hrl").

select_test() ->
    Q1 = {select, [], "user"},
    S1 = <<"SELECT * FROM \"user\"">>,
    ?assertEqual(S1, erma:build(Q1)),

    Q2 = {select, ["first_name", "last_name", "address.state"], "user",
          [{where, [{"email", "some@where.com"}]}]},
    S2 = <<"SELECT first_name, last_name, address.\"state\" FROM \"user\" ",
           "WHERE email = 'some@where.com'">>,
    ?assertEqual(S2, erma:build(Q2)),

    Q3 = {select, ["id", "username"], "users",
          [{where, [{"username", "chris"}]},
           {order, ["created"]},
           {offset, 3, limit, 5}]},
    S3 = <<"SELECT id, username FROM users ",
           "WHERE username = 'chris' ",
           "ORDER BY created ASC ",
           "OFFSET 3 LIMIT 5">>,
    ?assertEqual(S3, erma:build(Q3)),
    ok.


insert_test() ->
    Q1 = {insert, "users", ["first", "last", "age"], ["Bob", "Dou", 25]},
    S1 = <<"INSERT INTO users (\"first\", \"last\", age) VALUES ('Bob', 'Dou', 25)">>,
    ?assertEqual(S1, erma:build(Q1)),

    Q2 = {insert_rows, "users", ["first", "last", "age"],
          [["Bill", "Foo", 24], ["Bob", "Dou", 25], ["Helen", "Rice", 21]]},
    S2 = <<"INSERT INTO users (\"first\", \"last\", age) ",
           "VALUES ('Bill', 'Foo', 24), ('Bob', 'Dou', 25), ('Helen', 'Rice', 21)">>,
    ?assertEqual(S2, erma:build(Q2)),

    Q3 = {insert_rows, "users", [],
          [[1, "Bob", "Dou", 65], [6, "Bill", "Foo", 31]],
          [{returning, id}]},
    S3 = <<"INSERT INTO users "
           "VALUES (1, 'Bob', 'Dou', 65), (6, 'Bill', 'Foo', 31) ",
           "RETURNING id">>,
    ?assertEqual(S3, erma:build(Q3)),
    ok.


update_test() ->
    Q1 = {update, "users",
          [{"first", "Chris"},
           {"last", "Granger"}],
          [{where, [{"id", 3}]}]},
    S1 = <<"UPDATE users SET \"first\" = 'Chris', \"last\" = 'Granger' WHERE id = 3">>,
    ?assertEqual(S1, erma:build(Q1)),

    Q2 = {update, "users", [{"first", "Chris"}, {"last", "?"}], [{where, [{"id", "?"}]}]},
    S2 = <<"UPDATE users SET \"first\" = 'Chris', \"last\" = ? WHERE id = ?">>,
    ?assertEqual(S2, erma:build(Q2)),

    Q3 = {update, "users", [{"first", "Chris"}, {"last", "Granger"}],
          [{where, [{"id", 3}]}, {returning, id}]},
    S3 = <<"UPDATE users SET \"first\" = 'Chris', \"last\" = 'Granger' ",
           "WHERE id = 3 RETURNING id">>,
    ?assertEqual(S3, erma:build(Q3)),
    ok.


delete_test() ->
    Q1 = {delete, "users", [{where, [{"id", 3}]}]},
    S1 = <<"DELETE FROM users WHERE id = 3">>,
    ?assertEqual(S1, erma:build(Q1)),

    Q2 = {delete, "users", [{where, [{"id", 3}]}, {returning, id}]},
    S2 = <<"DELETE FROM users WHERE id = 3 RETURNING id">>,
    ?assertEqual(S2, erma:build(Q2)),
    ok.


relations_test() ->
    Q1 = {select, ["email.email", "address.state", "account.name"], "user",
          [{joins, [{left, "email"},
                    {left, <<"address">>},
                    {left, account}]}]},
    S1 = <<"SELECT email.email, address.\"state\", account.\"name\" FROM \"user\" ",
           "LEFT JOIN email ON email.id = \"user\".email_id ",
           "LEFT JOIN address ON address.id = \"user\".address_id ",
           "LEFT JOIN account ON account.id = \"user\".account_id">>,
    ?assertEqual(S1, erma:build(Q1)),

    Q2 = {select, ["email.email", "address.state", "account.name"], {"user", as, "u"},
          [{joins, [{left, {"email", as, "e"}, [{pk, "eid"}]},
                    {right, "address", [{fk, "addr_id"}]},
                    {full, "account", [{pk, "aid"}, {fk, "acc_id"}]}]}]},
    S2 = <<"SELECT email.email, address.\"state\", account.\"name\" FROM \"user\" AS u ",
           "LEFT JOIN email AS e ON e.eid = u.email_id ",
           "RIGHT JOIN address ON address.id = u.addr_id ",
           "FULL JOIN account ON account.aid = u.acc_id">>,
    ?assertEqual(S2, erma:build(Q2)),
    ok.


where_test() ->
    Q1 = {select, [], "post",
          [{where, [{'or', [{"title", like, "%funny%"},
                            {"subject", like, "%funny%"},
                            {"content", like, "%funny%"}]}
                   ]}
          ]},
    S1 = <<"SELECT * FROM post ",
           "WHERE (title LIKE '%funny%' OR subject LIKE '%funny%' OR content LIKE '%funny%')">>,
    ?assertEqual(S1, erma:build(Q1)),


    Q2 = {select, [], "post",
          [{where, [{"state", in, ["active", "suspended", "unknown"]}]}
          ]},
    S2 = <<"SELECT * FROM post ",
           "WHERE \"state\" IN ('active', 'suspended', 'unknown')">>,
    ?assertEqual(S2, erma:build(Q2)),

    DT1 = {datetime, {{2014, 1, 1}, {22, 30, 0}}},
    DT2 = {datetime, {{2013, 12, 20}, {12, 15, 0}}},
    Q3 = {select, [], "post",
          [{where, [{'or', [{"title", like, "%funny%"},
                            {"subject", like, "%funny%"},
                            {"content", like, "%funny%"}]},
                    {'and', [{"blocked", false},
                             {'or', [{"posted", '>', DT1},
                                     {"posted", '<', DT2}]}]},
                    {'not', {'or', [{"user_id", 20},
                                    {"user_id", 30}]}},
                    {"state", in, ["active", "suspended", "unknown"]}
                   ]}
          ]},
    S3 = <<"SELECT * FROM post ",
           "WHERE (title LIKE '%funny%' OR subject LIKE '%funny%' OR content LIKE '%funny%') ",
           "AND (blocked = false AND "
           "(posted > '2014-01-01 22:30:00' OR posted < '2013-12-20 12:15:00')) ",
           "AND (NOT (user_id = 20 OR user_id = 30)) ",
           "AND \"state\" IN ('active', 'suspended', 'unknown')">>,
    ?assertEqual(S3, erma:build(Q3)),
    ok.


append_test() ->
    Q1 = {select, [], "post"},
    S1 = <<"SELECT * FROM post">>,
    ?assertEqual(S1, erma:build(Q1)),

    Q2 = erma:append(Q1, [{where, [{"user_id", 10}]}]),
    S2 = <<"SELECT * FROM post WHERE user_id = 10">>,
    ?assertEqual(S2, erma:build(Q2)),

    Q3 = erma:append(Q2, [{where, [{'not', {"blocked", true}},
                                   {"posted", '>', {date, {2014, 2, 20}}}]}]),
    S3 = <<"SELECT * FROM post ",
           "WHERE user_id = 10 AND (NOT blocked = true) AND posted > '2014-02-20'">>,
    ?assertEqual(S3, erma:build(Q3)),

    Q4 = {select, ["u.id", "email.email", "a.state", "account.name"], {"user", as, "u"},
          [{joins, [{left, "email"}]}]},
    Q5 = erma:append(Q4, [{joins, [{left, {"address", as, "a"}}, {right, "account"}]}]),
    S5 = <<"SELECT u.id, email.email, \"a\".\"state\", account.\"name\" ",
           "FROM \"user\" AS u ",
           "LEFT JOIN email ON email.id = u.email_id ",
           "LEFT JOIN address AS \"a\" ON \"a\".id = u.address_id ",
           "RIGHT JOIN account ON account.id = u.account_id">>,
    ?assertEqual(S5, erma:build(Q5)),
    ok.
