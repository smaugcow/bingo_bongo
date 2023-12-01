CREATE INDEX sessions_customer_id_idx ON sessions(customer_id);
CREATE INDEX sessions_movie_id_idx ON sessions(movie_id);
CREATE INDEX sessions_customer_movie_idx ON sessions(customer_id, movie_id);

CREATE INDEX customers_name_idx ON customers(name);
CREATE INDEX movies_name_idx ON movies(name);

CREATE INDEX sessions_customer_id_idx ON sessions(customer_id);
CREATE INDEX sessions_movie_id_idx ON sessions(movie_id);
CREATE INDEX customers_id_name_surname_idx ON customers(id, name, surname);
CREATE INDEX movies_id_name_year_idx ON movies(id, name, year);

CREATE INDEX movies_year_name_idx ON movies(year DESC, name ASC);
CREATE INDEX customers_id_idx ON customers(id);
CREATE INDEX sessions_id_idx ON sessions(id DESC);
