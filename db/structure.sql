SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: contributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contributions (
    id bigint NOT NULL,
    photo_id bigint NOT NULL,
    user_id bigint NOT NULL,
    field_name character varying NOT NULL,
    value text NOT NULL,
    note text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: contributions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contributions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contributions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contributions_id_seq OWNED BY public.contributions.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id bigint NOT NULL,
    family_id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    location_id bigint,
    date_type character varying DEFAULT 'unknown'::character varying,
    year_from integer,
    month_from integer,
    day_from integer,
    season_from character varying,
    circa_from boolean DEFAULT false,
    year_to integer,
    month_to integer,
    day_to integer,
    season_to character varying,
    circa_to boolean DEFAULT false,
    date_display character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: face_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.face_regions (
    id bigint NOT NULL,
    photo_id bigint NOT NULL,
    person_id bigint,
    x double precision NOT NULL,
    y double precision NOT NULL,
    width double precision NOT NULL,
    height double precision NOT NULL,
    embedding public.vector(512),
    confidence double precision,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: face_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.face_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: face_regions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.face_regions_id_seq OWNED BY public.face_regions.id;


--
-- Name: families; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.families (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: families_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.families_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: families_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.families_id_seq OWNED BY public.families.id;


--
-- Name: family_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.family_memberships (
    id bigint NOT NULL,
    family_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: family_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.family_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: family_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.family_memberships_id_seq OWNED BY public.family_memberships.id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id bigint NOT NULL,
    family_id bigint NOT NULL,
    name character varying NOT NULL,
    address_line_1 character varying,
    address_line_2 character varying,
    city character varying,
    region character varying,
    postal_code character varying,
    country character varying,
    latitude numeric(10,6),
    longitude numeric(10,6),
    ancestry character varying COLLATE pg_catalog."C",
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.locations_id_seq OWNED BY public.locations.id;


--
-- Name: login_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.login_codes (
    id bigint NOT NULL,
    code character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: login_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.login_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: login_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.login_codes_id_seq OWNED BY public.login_codes.id;


--
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id bigint NOT NULL,
    family_id bigint NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    maiden_name character varying,
    date_of_birth date,
    date_of_death date,
    bio text,
    user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.people_id_seq OWNED BY public.people.id;


--
-- Name: photo_faces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photo_faces (
    id bigint NOT NULL,
    photo_id bigint NOT NULL,
    person_id bigint,
    tagged_by_id bigint,
    x numeric(8,6) NOT NULL,
    y numeric(8,6) NOT NULL,
    width numeric(8,6) NOT NULL,
    height numeric(8,6) NOT NULL,
    confidence numeric(8,6),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT photo_faces_height_range CHECK (((height > (0)::numeric) AND (height <= (1)::numeric))),
    CONSTRAINT photo_faces_width_range CHECK (((width > (0)::numeric) AND (width <= (1)::numeric))),
    CONSTRAINT photo_faces_x_range CHECK (((x >= (0)::numeric) AND (x <= (1)::numeric))),
    CONSTRAINT photo_faces_x_width_range CHECK (((x + width) <= (1)::numeric)),
    CONSTRAINT photo_faces_y_height_range CHECK (((y + height) <= (1)::numeric)),
    CONSTRAINT photo_faces_y_range CHECK (((y >= (0)::numeric) AND (y <= (1)::numeric)))
);


--
-- Name: photo_faces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.photo_faces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: photo_faces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.photo_faces_id_seq OWNED BY public.photo_faces.id;


--
-- Name: photo_people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photo_people (
    id bigint NOT NULL,
    photo_id bigint NOT NULL,
    person_id bigint NOT NULL,
    tagged_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: photo_people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.photo_people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: photo_people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.photo_people_id_seq OWNED BY public.photo_people.id;


--
-- Name: photo_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photo_sources (
    id bigint NOT NULL,
    photo_id bigint NOT NULL,
    description character varying NOT NULL,
    source_person_id bigint,
    scanned_by_person_id bigint,
    scanned_at date,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: photo_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.photo_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: photo_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.photo_sources_id_seq OWNED BY public.photo_sources.id;


--
-- Name: photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photos (
    id bigint NOT NULL,
    family_id bigint NOT NULL,
    title character varying,
    description text,
    event_id bigint,
    location_id bigint,
    photographer_id bigint,
    date_type character varying DEFAULT 'unknown'::character varying,
    year integer,
    month integer,
    day integer,
    season character varying,
    circa boolean DEFAULT false,
    date_display character varying,
    width integer,
    height integer,
    file_size integer,
    original_filename character varying,
    content_type character varying,
    uploaded_by_id bigint,
    upload_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    file_modified_at timestamp(6) without time zone,
    taken_at timestamp(6) without time zone,
    faces_analyzed_at timestamp without time zone,
    orientation_corrected boolean DEFAULT false,
    orientation_correction integer DEFAULT 0
);


--
-- Name: photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.photos_id_seq OWNED BY public.photos.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    family_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uploads (
    id bigint NOT NULL,
    family_id bigint NOT NULL,
    user_id bigint NOT NULL,
    source_album character varying,
    scanned_at date,
    notes text,
    photos_count integer DEFAULT 0,
    date_type character varying DEFAULT 'unknown'::character varying,
    year_from integer,
    year_to integer,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    source_owner_id bigint,
    scanned_by_person_id bigint
);


--
-- Name: uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.uploads_id_seq OWNED BY public.uploads.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying NOT NULL,
    email character varying,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: contributions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions ALTER COLUMN id SET DEFAULT nextval('public.contributions_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: face_regions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_regions ALTER COLUMN id SET DEFAULT nextval('public.face_regions_id_seq'::regclass);


--
-- Name: families id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.families ALTER COLUMN id SET DEFAULT nextval('public.families_id_seq'::regclass);


--
-- Name: family_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.family_memberships ALTER COLUMN id SET DEFAULT nextval('public.family_memberships_id_seq'::regclass);


--
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations ALTER COLUMN id SET DEFAULT nextval('public.locations_id_seq'::regclass);


--
-- Name: login_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_codes ALTER COLUMN id SET DEFAULT nextval('public.login_codes_id_seq'::regclass);


--
-- Name: people id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people ALTER COLUMN id SET DEFAULT nextval('public.people_id_seq'::regclass);


--
-- Name: photo_faces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_faces ALTER COLUMN id SET DEFAULT nextval('public.photo_faces_id_seq'::regclass);


--
-- Name: photo_people id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_people ALTER COLUMN id SET DEFAULT nextval('public.photo_people_id_seq'::regclass);


--
-- Name: photo_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_sources ALTER COLUMN id SET DEFAULT nextval('public.photo_sources_id_seq'::regclass);


--
-- Name: photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos ALTER COLUMN id SET DEFAULT nextval('public.photos_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: uploads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads ALTER COLUMN id SET DEFAULT nextval('public.uploads_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: contributions contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: face_regions face_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_regions
    ADD CONSTRAINT face_regions_pkey PRIMARY KEY (id);


--
-- Name: families families_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.families
    ADD CONSTRAINT families_pkey PRIMARY KEY (id);


--
-- Name: family_memberships family_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.family_memberships
    ADD CONSTRAINT family_memberships_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: login_codes login_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_codes
    ADD CONSTRAINT login_codes_pkey PRIMARY KEY (id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: photo_faces photo_faces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_faces
    ADD CONSTRAINT photo_faces_pkey PRIMARY KEY (id);


--
-- Name: photo_people photo_people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_people
    ADD CONSTRAINT photo_people_pkey PRIMARY KEY (id);


--
-- Name: photo_sources photo_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_sources
    ADD CONSTRAINT photo_sources_pkey PRIMARY KEY (id);


--
-- Name: photos photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT photos_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: uploads uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT uploads_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_contributions_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_photo_id ON public.contributions USING btree (photo_id);


--
-- Name: index_contributions_on_photo_id_and_field_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_photo_id_and_field_name ON public.contributions USING btree (photo_id, field_name);


--
-- Name: index_contributions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_user_id ON public.contributions USING btree (user_id);


--
-- Name: index_events_on_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_family_id ON public.events USING btree (family_id);


--
-- Name: index_events_on_family_id_and_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_family_id_and_title ON public.events USING btree (family_id, title);


--
-- Name: index_events_on_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_location_id ON public.events USING btree (location_id);


--
-- Name: index_events_on_year_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_year_from ON public.events USING btree (year_from);


--
-- Name: index_face_regions_on_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_regions_on_person_id ON public.face_regions USING btree (person_id);


--
-- Name: index_face_regions_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_face_regions_on_photo_id ON public.face_regions USING btree (photo_id);


--
-- Name: index_family_memberships_on_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_family_memberships_on_family_id ON public.family_memberships USING btree (family_id);


--
-- Name: index_family_memberships_on_family_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_family_memberships_on_family_id_and_user_id ON public.family_memberships USING btree (family_id, user_id);


--
-- Name: index_family_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_family_memberships_on_user_id ON public.family_memberships USING btree (user_id);


--
-- Name: index_locations_on_ancestry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_locations_on_ancestry ON public.locations USING btree (ancestry);


--
-- Name: index_locations_on_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_locations_on_family_id ON public.locations USING btree (family_id);


--
-- Name: index_locations_on_family_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_locations_on_family_id_and_name ON public.locations USING btree (family_id, name);


--
-- Name: index_login_codes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_login_codes_on_user_id ON public.login_codes USING btree (user_id);


--
-- Name: index_people_on_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_family_id ON public.people USING btree (family_id);


--
-- Name: index_people_on_family_id_and_last_name_and_first_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_family_id_and_last_name_and_first_name ON public.people USING btree (family_id, last_name, first_name);


--
-- Name: index_people_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_people_on_user_id ON public.people USING btree (user_id);


--
-- Name: index_photo_faces_on_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_faces_on_person_id ON public.photo_faces USING btree (person_id);


--
-- Name: index_photo_faces_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_faces_on_photo_id ON public.photo_faces USING btree (photo_id);


--
-- Name: index_photo_faces_on_photo_id_and_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_faces_on_photo_id_and_person_id ON public.photo_faces USING btree (photo_id, person_id);


--
-- Name: index_photo_faces_on_tagged_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_faces_on_tagged_by_id ON public.photo_faces USING btree (tagged_by_id);


--
-- Name: index_photo_people_on_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_people_on_person_id ON public.photo_people USING btree (person_id);


--
-- Name: index_photo_people_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_people_on_photo_id ON public.photo_people USING btree (photo_id);


--
-- Name: index_photo_people_on_photo_id_and_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_photo_people_on_photo_id_and_person_id ON public.photo_people USING btree (photo_id, person_id);


--
-- Name: index_photo_people_on_tagged_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_people_on_tagged_by_id ON public.photo_people USING btree (tagged_by_id);


--
-- Name: index_photo_sources_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_sources_on_photo_id ON public.photo_sources USING btree (photo_id);


--
-- Name: index_photo_sources_on_scanned_by_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_sources_on_scanned_by_person_id ON public.photo_sources USING btree (scanned_by_person_id);


--
-- Name: index_photo_sources_on_source_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photo_sources_on_source_person_id ON public.photo_sources USING btree (source_person_id);


--
-- Name: index_photos_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_created_at ON public.photos USING btree (created_at);


--
-- Name: index_photos_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_event_id ON public.photos USING btree (event_id);


--
-- Name: index_photos_on_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_family_id ON public.photos USING btree (family_id);


--
-- Name: index_photos_on_family_id_and_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_family_id_and_year ON public.photos USING btree (family_id, year);


--
-- Name: index_photos_on_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_location_id ON public.photos USING btree (location_id);


--
-- Name: index_photos_on_photographer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_photographer_id ON public.photos USING btree (photographer_id);


--
-- Name: index_photos_on_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_upload_id ON public.photos USING btree (upload_id);


--
-- Name: index_photos_on_uploaded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_uploaded_by_id ON public.photos USING btree (uploaded_by_id);


--
-- Name: index_sessions_on_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_family_id ON public.sessions USING btree (family_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_uploads_on_family_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_family_id ON public.uploads USING btree (family_id);


--
-- Name: index_uploads_on_scanned_by_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_scanned_by_person_id ON public.uploads USING btree (scanned_by_person_id);


--
-- Name: index_uploads_on_source_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_source_owner_id ON public.uploads USING btree (source_owner_id);


--
-- Name: index_uploads_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_user_id ON public.uploads USING btree (user_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: sessions fk_rails_008172463f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_008172463f FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: locations fk_rails_0bc9ea5294; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT fk_rails_0bc9ea5294 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: photo_sources fk_rails_0f8dbd513c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_sources
    ADD CONSTRAINT fk_rails_0f8dbd513c FOREIGN KEY (source_person_id) REFERENCES public.people(id);


--
-- Name: uploads fk_rails_15d41e668d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT fk_rails_15d41e668d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: face_regions fk_rails_1605e57d5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_regions
    ADD CONSTRAINT fk_rails_1605e57d5a FOREIGN KEY (photo_id) REFERENCES public.photos(id);


--
-- Name: photos fk_rails_1dee3b50b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT fk_rails_1dee3b50b5 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: photo_people fk_rails_1df8a0fac3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_people
    ADD CONSTRAINT fk_rails_1df8a0fac3 FOREIGN KEY (photo_id) REFERENCES public.photos(id);


--
-- Name: photo_sources fk_rails_2a906834d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_sources
    ADD CONSTRAINT fk_rails_2a906834d2 FOREIGN KEY (scanned_by_person_id) REFERENCES public.people(id);


--
-- Name: photo_sources fk_rails_30b0de223c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_sources
    ADD CONSTRAINT fk_rails_30b0de223c FOREIGN KEY (photo_id) REFERENCES public.photos(id);


--
-- Name: uploads fk_rails_3cbb69f58f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT fk_rails_3cbb69f58f FOREIGN KEY (scanned_by_person_id) REFERENCES public.people(id);


--
-- Name: events fk_rails_3d0bd29ec6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_3d0bd29ec6 FOREIGN KEY (location_id) REFERENCES public.locations(id);


--
-- Name: photos fk_rails_455c7c0f91; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT fk_rails_455c7c0f91 FOREIGN KEY (uploaded_by_id) REFERENCES public.users(id);


--
-- Name: photos fk_rails_47f4e5f105; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT fk_rails_47f4e5f105 FOREIGN KEY (location_id) REFERENCES public.locations(id);


--
-- Name: photo_faces fk_rails_4cc5129401; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_faces
    ADD CONSTRAINT fk_rails_4cc5129401 FOREIGN KEY (photo_id) REFERENCES public.photos(id);


--
-- Name: events fk_rails_7377fccfe5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_7377fccfe5 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: family_memberships fk_rails_818aa4a9f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.family_memberships
    ADD CONSTRAINT fk_rails_818aa4a9f9 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: family_memberships fk_rails_829cfb2ffc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.family_memberships
    ADD CONSTRAINT fk_rails_829cfb2ffc FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: uploads fk_rails_897e321130; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT fk_rails_897e321130 FOREIGN KEY (source_owner_id) REFERENCES public.people(id);


--
-- Name: contributions fk_rails_9089fe7626; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT fk_rails_9089fe7626 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: photo_people fk_rails_91091ea1ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_people
    ADD CONSTRAINT fk_rails_91091ea1ca FOREIGN KEY (tagged_by_id) REFERENCES public.users(id);


--
-- Name: people fk_rails_976628f7ec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT fk_rails_976628f7ec FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: uploads fk_rails_9ff5c5af70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT fk_rails_9ff5c5af70 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: photos fk_rails_a6d4530880; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT fk_rails_a6d4530880 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: people fk_rails_b39dcee1e8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT fk_rails_b39dcee1e8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: photo_faces fk_rails_b77bdadfa9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_faces
    ADD CONSTRAINT fk_rails_b77bdadfa9 FOREIGN KEY (person_id) REFERENCES public.people(id);


--
-- Name: photo_people fk_rails_bd6bd911d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_people
    ADD CONSTRAINT fk_rails_bd6bd911d9 FOREIGN KEY (person_id) REFERENCES public.people(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: photo_faces fk_rails_c4331e7db2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photo_faces
    ADD CONSTRAINT fk_rails_c4331e7db2 FOREIGN KEY (tagged_by_id) REFERENCES public.users(id);


--
-- Name: photos fk_rails_c58be3102d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT fk_rails_c58be3102d FOREIGN KEY (photographer_id) REFERENCES public.people(id);


--
-- Name: photos fk_rails_c66f96306e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT fk_rails_c66f96306e FOREIGN KEY (upload_id) REFERENCES public.uploads(id);


--
-- Name: contributions fk_rails_da65ca7f1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT fk_rails_da65ca7f1c FOREIGN KEY (photo_id) REFERENCES public.photos(id);


--
-- Name: face_regions fk_rails_e69c642dcb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.face_regions
    ADD CONSTRAINT fk_rails_e69c642dcb FOREIGN KEY (person_id) REFERENCES public.people(id);


--
-- Name: login_codes fk_rails_f8423fb01a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.login_codes
    ADD CONSTRAINT fk_rails_f8423fb01a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260301205107'),
('20260301084500'),
('20260301000002'),
('20260301000001'),
('20260228223620'),
('20260228223125'),
('20260228222153'),
('20260228215724'),
('20260228215723'),
('20260228215722'),
('20260228215721'),
('20260228215720'),
('20260228215719'),
('20260228215718'),
('20260228215717'),
('20260228215716'),
('20260228215715'),
('20260228215714'),
('20260228215713'),
('20260228215712'),
('20260228215711');

