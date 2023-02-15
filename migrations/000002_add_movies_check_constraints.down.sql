-- We could have just included the CHECK constraints along with 
-- the CREATE TABLE statement in the first pair of migration files,
-- but for the purpose of this book having them in a separate 
-- second migration helps us to illustrate how the migrate tool works.
ALTER TABLE movies DROP CONSTRAINT IF EXISTS movies_runtime_check; 

ALTER TABLE movies DROP CONSTRAINT IF EXISTS movies_year_check; 

ALTER TABLE movies DROP CONSTRAINT IF EXISTS genres_length_check;