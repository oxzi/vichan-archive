--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.6
-- Dumped by pg_dump version 9.5.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: posts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE posts (
    board character varying(64) NOT NULL,
    no integer NOT NULL,
    thread_no integer NOT NULL,
    "time" bigint NOT NULL,
    name character varying(128),
    com text,
    existing boolean NOT NULL
);


ALTER TABLE posts OWNER TO postgres;

--
-- Name: boards; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW boards AS
 SELECT posts.board,
    count(*) AS posts
   FROM posts
  GROUP BY posts.board
  ORDER BY posts.board;


ALTER TABLE boards OWNER TO postgres;

--
-- Name: threads; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW threads AS
 SELECT posts.board,
    posts.thread_no,
    count(posts.thread_no) AS posts,
    max(posts."time") AS last_post_time
   FROM posts
  GROUP BY posts.board, posts.thread_no
  ORDER BY (max(posts."time")) DESC;


ALTER TABLE threads OWNER TO postgres;

--
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY posts (board, no, thread_no, "time", name, com, existing) FROM stdin;
\.


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (board, no);


--
-- Name: posts_board_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_board_fkey FOREIGN KEY (board, thread_no) REFERENCES posts(board, no);


--
-- Name: public; Type: ACL; Schema: -; Owner: root
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM root;
GRANT ALL ON SCHEMA public TO root;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

