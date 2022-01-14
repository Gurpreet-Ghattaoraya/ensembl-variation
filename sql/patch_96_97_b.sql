-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2022] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


ALTER TABLE variation_feature ADD COLUMN ancestral_allele varchar(50) DEFAULT NULL AFTER allele_string; 

UPDATE variation_feature vf, variation v SET vf.ancestral_allele = v.ancestral_allele WHERE vf.variation_id = v.variation_id;

ALTER TABLE variation DROP ancestral_allele;


# patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'patch', 'patch_96_97_b.sql|move ancestral allele column to variation_feature');
