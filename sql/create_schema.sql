-- name: create_schema#
-- Prepare a metabolic reference knowledge base database schema

-- CREATE TYPE TEXT AS ENUM ('left-to-right', 'right-to-left');

CREATE TABLE substrate (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT pk_substrate PRIMARY KEY (id),
    CONSTRAINT unique_substrate UNIQUE (name)
); 

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
    CONSTRAINT pk_compound PRIMARY KEY (id),
    CONSTRAINT unique_compound_name UNIQUE (name)
);

CREATE TABLE compound_name_synonymes (
    compound_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT pk_compound_name PRIMARY KEY (compound_id, name),
    CONSTRAINT fk_compound_name_compound_id FOREIGN KEY (compound_id) REFERENCES compound (id),
    CONSTRAINT unique_compound_name_name UNIQUE (name)
);


CREATE TABLE reaction (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    type TEXT, -- either Chemical-Reaction, Biochemical-Reaction, RNA-Reaction -- TODO: see if it is required.
    comment TEXT,
    ec_number TEXT,
    spontaneous BOOLEAN,
    gibbs_free_energy FLOAT, -- GIBBS-0: DeltaRG°0 (?)
    physiologically_relevant BOOLEAN,
    reaction_balance_status BOOLEAN,
    reaction_physiological_direction TEXT, -- either 'right' or 'left'
    CONSTRAINT pk_reaction PRIMARY KEY (id),
    CONSTRAINT unique_reaction_name UNIQUE (name)
);

CREATE TABLE reaction_name (
    id INTEGER NOT NULL,
    reaction_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT pk_reaction_name PRIMARY KEY (id),
    CONSTRAINT fk_reaction_name_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id)
);

CREATE TABLE reaction_species (
    reaction_id INTEGER NOT NULL,
    species_id INTEGER NOT NULL,
    CONSTRAINT pk_reaction_species PRIMARY KEY (reaction_id, species_id),
    CONSTRAINT fk_reaction_species_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id)
);

CREATE TABLE reaction_substrate (
    id INTEGER NOT NULL,
    reaction_id INTEGER NOT NULL,  
    substrate_id INTEGER NOT NULL,
    stoechiometry INTEGER,
    reaction_side TEXT, -- 'left' or 'right'
    CONSTRAINT pk_reaction_substrate PRIMARY KEY (id),
    CONSTRAINT fk_reaction_substrate_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id),
    CONSTRAINT fk_reaction_substrate_substrate_id FOREIGN KEY (substrate_id) REFERENCES chemical (id)
);

CREATE TABLE polypeptide (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    comment TEXT,
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
    complex_id INTEGER NOT NULL,
    component_id INTEGER NOT NULL,
    coefficient INTEGER,
    CONSTRAINT pk_polypeptide_complex_component PRIMARY KEY (complex_id, component_id),
    CONSTRAINT fk_polypeptide_complex_component_complex_id FOREIGN KEY (complex_id) REFERENCES polypeptide (id),
    CONSTRAINT fk_polypeptide_complex_component_component_id FOREIGN KEY (component_id) REFERENCES polypeptide (id)
);

CREATE TABLE reaction_enzyme (
    reaction_id INTEGER NOT NULL,
    enzyme_id INTEGER NOT NULL,
    CONSTRAINT pk_enzymatic_reaction PRIMARY KEY (reaction_id, enzyme_id),
    CONSTRAINT fk_enzymatic_reaction_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id),
    CONSTRAINT fk_enzymatic_reaction_enzyme_id FOREIGN KEY (enzyme_id) REFERENCES polypeptide (id)
);

CREATE TABLE pathway (
    id INTEGER NOT NULL,
    name TEXT NOT NULL,
    comment TEXT,
    CONSTRAINT pk_pathway PRIMARY KEY (id),
    CONSTRAINT unique_pathway_name UNIQUE (name)
);


CREATE TABLE pathway_name_synonymes (
    pathway_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT pk_pathway_name PRIMARY KEY (pathway_id, name),
    CONSTRAINT fk_pathway_name_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id)
);


CREATE TABLE pathway_sub_pathway (
    super_pathway_id INTEGER NOT NULL,
    sub_pathway_id INTEGER NOT NULL,
    CONSTRAINT pk_sub_pathway PRIMARY KEY (super_pathway_id, sub_pathway_id),
    CONSTRAINT fk_sub_pathway_super_pathway_id FOREIGN KEY (super_pathway_id) REFERENCES pathway (id),
    CONSTRAINT fk_sub_pathway_sub_pathway_id FOREIGN KEY (sub_pathway_id) REFERENCES pathway (id)    
);

-- A pathway reaction graph
--
-- represents the arcs wihin a directed reaction graph of a given pathway
CREATE TABLE pathway_reaction_graph (
    pathway_id INTEGER NOT NULL,
    predecessor_reaction_id INTEGER NOT NULL,
    successor_reaction_id INTEGER NOT NULL,
    CONSTRAINT pk_pathway_reaction_graph PRIMARY KEY (pathway_id, predecessor_reaction_id, successor_reaction_id),
    CONSTRAINT fk_pathway_reaction_graph_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id),
    CONSTRAINT fk_pathway_reaction_graph_predecessor_reaction_id FOREIGN KEY (predecessor_reaction_id) REFERENCES reaction (id),
    CONSTRAINT fk_pathway_reaction_graph_successor_reaction_id FOREIGN KEY (successor_reaction_id) REFERENCES reaction (id)
); 

-- CREATE TABLE pathway_reaction_metabolite_graph (
--     pathway_id INTEGER NOT NULL,
--     reaction_id INTEGER NOT NULL,
--     metabolite_id INTEGER NOT NULL,
--     reaction_direction TEXT NOT NULL,
--     CONSTRAINT pk_pathway_reaction_metabolite_graph PRIMARY KEY (pathway_id, reaction_id, metabolite_id),
--     CONSTRAINT fk_pathway_reaction_metabolite_graph_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id),
--     CONSTRAINT fk_pathway_reaction_metabolite_graph_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id),
--     CONSTRAINT fk_pathway_reaction_metabolite_graph_metabolite_id FOREIGN KEY (metabolite_id) REFERENCES substrate (id)
-- );

-- 
CREATE TABLE pathway_reaction (
    pathway_id INTEGER NOT NULL,
    reaction_id INTEGER NOT NULL,
    reaction_direction TEXT,
    CONSTRAINT pk_pathway_reaction PRIMARY KEY (pathway_id, reaction_id),
    CONSTRAINT fk_pathway_reaction_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id),
    CONSTRAINT fk_pathway_reaction_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id) 
);

CREATE TABLE pathway_key_reaction (
    pathway_id INTEGER NOT NULL,
    reaction_id INTEGER NOT NULL,
    CONSTRAINT pk_pathway_key_reaction PRIMARY KEY (pathway_id, reaction_id),
    CONSTRAINT fk_pathway_key_reaction_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id),
    CONSTRAINT fk_pathway_key_reaction_reaction_id FOREIGN KEY (reaction_id) REFERENCES reaction (id) 
);

CREATE TABLE pathway_species (
    pathway_id INTEGER NOT NULL,
    species_id INTEGER NOT NULL,
    CONSTRAINT pk_pathway_species PRIMARY KEY (pathway_id, species_id),
    CONSTRAINT fk_pathway_species_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id),
    CONSTRAINT fk_pathway_species_species_id FOREIGN KEY (species_id) REFERENCES taxon (id)
);

CREATE TABLE pathway_taxonomic_range (
    pathway_id INTEGER NOT NULL,
    taxon_id INTEGER NOT NULL,
    CONSTRAINT pk_pathway_taxonomic_range PRIMARY KEY (pathway_id, taxon_id),
    CONSTRAINT fk_pathway_taxonomic_range_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id)
--    CONSTRAINT fk_pathway_taxonomic_range_taxon_id FOREIGN KEY (taxon_id) REFERENCES taxon (id)
);

CREATE TABLE pathway_variant (
    pathway_id INTEGER NOT NULL,
    variant_id INTEGER NOT NULL,
    CONSTRAINT pk_pathway_variant PRIMARY KEY (pathway_id, variant_id),
    CONSTRAINT fk_pathway_variant_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id),
    CONSTRAINT fk_pathway_variant_variant_id FOREIGN KEY (variant_id) REFERENCES pathway (id)
);

CREATE TABLE pathway_variant_group (
    variant_group_id INTEGER NOT NULL,
    variant_id INTEGER NOT NULL,
    CONSTRAINT pk_pathway_variant_group PRIMARY KEY (variant_group_id, variant_id),
    CONSTRAINT fk_pathway_variant_group_variant_id FOREIGN KEY (variant_id) REFERENCES pathway (id)
);

CREATE TABLE pathway_ontology (
    pathway_id INTEGER NOT NULL,
    path INTEGER NOT NULL,
    depth INTEGER NOT NULL,
    pathway_class TEXT NOT NULL,
    CONSTRAINT pk_pathway_ontology PRIMARY KEY (pathway_id, path, depth, pathway_class),
    CONSTRAINT fk_pathway_ontology_pathway_id FOREIGN KEY (pathway_id) REFERENCES pathway (id)
);


-- TABLE secondary index
CREATE UNIQUE INDEX IF NOT EXISTS idx_reaction_name ON reaction (name);
CREATE UNIQUE INDEX IF NOT EXISTS idx_substrate_name ON substrate (name);
CREATE UNIQUE INDEX IF NOT EXISTS idx_polypeptide_name ON polypeptide (name);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pathway_name ON pathway (name);
