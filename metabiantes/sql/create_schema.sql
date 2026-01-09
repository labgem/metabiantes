-- name: create_schema#
-- Prepare a metabolic reference knowledge base database schema

CREATE TABLE compound (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    type TEXT,
    comment TEXT,
    atomic_number INTEGER,
    atom_charges INTEGER,
    molecular_weight FLOAT,
    monoisotopic_mw FLOAT,
    smiles TEXT,
    gibbs_free_energy FLOAT,
    pka2 FLOAT,
    CONSTRAINT pk_compound PRIMARY KEY (id)
);

CREATE TABLE compound_name (
    id INTEGER NOT NULL,
    compound_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT pk_compound_name PRIMARY KEY (id),
    CONSTRAINT fk_compound_name_compound_id FOREIGN KEY (compound_id) REFERENCES compound (id)
);


CREATE TABLE reaction (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    type TEXT, -- either Chemical-Reaction, Biochemical-Reaction, RNA-Reaction -- TODO: see if it is required.    ec_number TEXT,
    comment TEXT,
    gibbs_free_energy FLOAT, -- GIBBS-0: DeltaRG°0 (?)
    physiologically_relevant BOOLEAN,
    reaction_balance_status BOOLEAN,
    reaction_physiological_direction TEXT, -- either 'right' or 'left'
    CONSTRAINT pk_reaction PRIMARY KEY (id),
    CONSTRAINT unique_name_reaction UNIQUE (name)
);

CREATE TABLE reaction_name (
    id INTEGER NOT NULL,
    reaction_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT pk_reaction_name PRIMARY KEY (id),
    CONSTRAINT fk_reaction_name_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id)
);

CREATE TABLE species (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    rank TEXT NOT NULL,
    CONSTRAINT pk_species PRIMARY KEY (id)
);

CREATE TABLE reaction_species (
    reaction_id INTEGER NOT NULL,
    species_id INTEGER NOT NULL,
    CONSTRAINT pk_reaction_species PRIMARY KEY (id),
    CONSTRAINT fk_reaction_species_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id),
    CONSTRAINT fk_reaction_species_species_id FOREIGN KEY (species_id) REFERENCES species (id)
);

CREATE TABLE reaction_substrate (
    id INTEGER NOT NULL,
    reaction_id INTEGER NOT NULL,  
    compound_id INTEGER NOT NULL,
    stoechiometry INTEGER,
    reaction_side TEXT, -- 'left' or 'right'
    CONSTRAINT pk_reaction_substrate PRIMARY KEY (id),
    CONSTRAINT fk_reaction_substrate_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id),
    CONSTRAINT fk_reaction_substrate_substrate_id FOREIGN KEY (compound_id) REFERENCES compound (id)
);

CREATE TABLE polypeptide (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    experimental_molecular_weight FLOAT,
    molecular_weight FLOAT,
    molecular_weight_sequence FLOAT,
    half_life FLOAT,
    gene TEXT,
    neidhardt_spot_number INTEGER,
    atom_charges INTEGER,
    isoelectric_point FLOAT,
    CONSTRAINT pk_polypeptide PRIMARY KEY (id)
);

CREATE TABLE polypeptide_complex_component (
    polypeptide_id INTEGER NOT NULL,
    component_polypeptide_id INTEGER NOT NULL,
    stoechiometry INTEGER,
    CONSTRAINT pk_polypeptide_complex_component (polypeptide_id, component_polypeptide_id),
    CONSTRAINT fk_polypeptide_complex_component_polypeptide_id FOREIGN KEY (polypeptide_id) REFERENCES polypeptide (id),
    CONSTRAINT fk_polypeptide_complex_component_component_polypeptide_id FOREIGN KEY (component_polypeptide_id) REFERENCES polypeptide (id)
);

CREATE TABLE enzymatic_reaction (
    reaction_id INTEGER NOT NULL,
    enzyme_id INTEGER NOT NULL,
    CONSTRAINT pk_enzymatic_reaction PRIMARY KEY (reaction_id, enzyme_id),
    CONSTRAINT fk_enzymatic_reaction_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id),
    CONSTRAINT fk_enzymatic_reaction_enzyme_id FOREIGN KEY (enzyme_id) REFERENCES polypeptide (id)
);

CREATE TABLE ec_number (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    CONSTRAINT pk_ec_number PRIMARY KEY (id)
);

