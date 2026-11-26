# Unjudged secondary domains of the membership.v3 calibration battery

59 secondary domains (second and later listed) were named by neither the gold `fair` nor its `bad` list, in 26 of 32 control items. The pre-registered precision (`precision_secondary` = 0.6919) counts every one against; the fair share of the judged secondaries is 0.9605 (6 bad of 152 judged). The pre-registered verdict stays the pre-registered metric; this file is for review (add each domain to the control's `fair` or `bad` list in `data/gold/membership_wide_controls_v0.jsonl` only by a recorded ruling).

## cal.d01 (decoy): A baker named Mason sells bread at the market

- form, variant 0: `c.entrepreneurship` (Entrepreneurship and small business), fit 5; list ['c.retail_work', 'c.entrepreneurship']
- form, variant 1: `c.entrepreneurship` (Entrepreneurship and small business), fit 5; list ['c.retail_work', 'c.sales_marketing', 'c.entrepreneurship']
- form, variant 1: `c.sales_marketing` (Sales, marketing and advertising), fit 6; list ['c.retail_work', 'c.sales_marketing', 'c.entrepreneurship']
- gold fair {'content': ['c.retail_shopping', 'c.food_purchasing', 'c.retail_work', 'c.cooking', 'c.income_earning'], 'form': ['c.retail_work', 'c.retail_shopping', 'c.food_purchasing']}; bad {'content': ['c.construction_trades'], 'form': ['c.construction_trades', 'c.skilled_trades']}

## cal.d02 (decoy): A woman buys a train ticket on a bank holiday

- content, variant 0: `s.mobility` (Travel, mobility and place), fit 6; list ['c.public_transport', 's.mobility']
- form, variant 1: `c.retail_shopping` (Retail shopping), fit 4; list ['c.shopping_errands', 'c.retail_shopping']
- form, variant 0: `s.consumption` (Consumption, money and property), fit 4; list ['c.shopping_errands', 'c.public_transport', 's.consumption']
- gold fair {'content': ['c.public_transport', 'c.tourism_travel', 'c.shopping_errands'], 'form': ['c.public_transport', 'c.tourism_travel', 'c.shopping_errands', 'c.online_commerce']}; bad {'content': ['c.banking_payments', 'c.celebrations'], 'form': ['c.banking_payments']}

## cal.d03 (decoy): A woman reads a recipe for tiger prawns

- content, variant 0: `c.eating_drinking` (Eating and drinking), fit 4; list ['c.cooking', 'c.eating_drinking']
- content, variant 1: `c.eating_drinking` (Eating and drinking), fit 4; list ['c.cooking', 'c.eating_drinking']
- gold fair {'content': ['c.cooking', 'c.nutrition_diet', 'c.reading'], 'form': ['c.reading', 'c.cooking']}; bad {'content': ['c.wildlife_conservation', 'c.fishing_hunting_foraging', 'c.animal_care_husbandry'], 'form': ['c.wildlife_conservation', 'c.fishing_hunting_foraging']}

## cal.d05 (decoy): A girl plays chess against her grandfather

- content, variant 0: `c.children_play` (Children's play), fit 4; list ['c.games_play', 'c.family_ties', 'c.children_play']
- form, variant 0: `c.socialising` (Socialising and visiting), fit 5; list ['c.games_play', 'c.socialising']
- gold fair {'content': ['c.games_play', 'c.family_ties'], 'form': ['c.games_play']}; bad {'content': ['c.sport_participation', 'c.mathematics', 'c.gambling', 'c.military_defence'], 'form': ['c.sport_participation', 'c.gambling', 'c.military_defence']}

## cal.m02 (multi): A village family grows maize and sells the surplus at the weekly market

- form, variant 0: `c.entrepreneurship` (Entrepreneurship and small business), fit 5; list ['c.horticulture_farming', 'c.agri_forestry_fishing_work', 'c.entrepreneurship']
- form, variant 1: `c.sales_marketing` (Sales, marketing and advertising), fit 5; list ['c.horticulture_farming', 'c.agri_forestry_fishing_work', 'c.sales_marketing']
- gold fair {'content': ['c.horticulture_farming', 'c.income_earning', 'c.agri_forestry_fishing_work', 'c.retail_shopping', 'c.self_provisioning', 'c.food_purchasing'], 'form': ['c.horticulture_farming', 'c.agri_forestry_fishing_work', 'c.retail_shopping', 'c.self_provisioning', 'c.income_earning'], 'setting': ['c.agri_forestry_fishing_work', 'c.retail_shopping', 'c.neighbours_community']}; bad {'content': ['c.animal_care_husbandry', 'c.taxation_compliance'], 'form': ['c.animal_care_husbandry', 'c.banking_payments']}

## cal.m03 (multi): A mother teaches her daughter to knit while they listen to the radio

- content, variant 0: `c.parenting_young_children` (Parenting young children), fit 5; list ['c.crafts_hobbies', 'c.family_ties', 'c.parenting_young_children']
- form, variant 0: `c.news_media` (News and information media), fit 4; list ['c.crafts_hobbies', 'c.tutoring_teaching', 'c.news_media']
- gold fair {'content': ['c.crafts_hobbies', 'c.family_ties', 'c.tutoring_teaching', 'c.music_listening', 'c.news_media', 'c.clothing_footwear'], 'form': ['c.crafts_hobbies', 'c.tutoring_teaching', 'c.parenting_young_children', 'c.parenting_adolescents', 'c.family_ties']}; bad {'content': ['c.school_education', 'c.manufacturing'], 'form': ['c.school_education', 'c.retail_shopping']}

## cal.m04 (multi): A couple moves to another country for his job and she enrols in a language course

- form, variant 0: `c.employment_job` (Having a job), fit 4; list ['c.moving_relocation', 'c.migration', 'c.language_learning', 'c.employment_job']
- form, variant 1: `c.employment_transition` (Job change and career moves), fit 5; list ['c.moving_relocation', 'c.migration', 'c.language_learning', 'c.employment_transition']
- gold fair {'content': ['c.migration', 'c.moving_relocation', 'c.employment_job', 'c.language_learning', 'c.marriage_cohabitation', 'c.border_migration_admin'], 'form': ['c.moving_relocation', 'c.migration', 'c.language_learning']}; bad {'content': ['c.tourism_travel', 'c.higher_education'], 'form': ['c.tourism_travel', 'c.air_travel']}

## cal.m05 (multi): A farmers' cooperative votes to fund a new irrigation canal after a drought

- form, variant 0: `c.saving_investing` (Saving and investing), fit 4; list ['c.voting_elections', 'c.community_groups', 'c.saving_investing']
- gold fair {'content': ['c.horticulture_farming', 'c.weather_climate_adaptation', 'c.community_groups', 'c.environmental_stewardship', 'c.civil_engineering', 'c.agri_forestry_fishing_work', 'c.disaster_experience'], 'form': ['c.voting_elections', 'c.political_participation', 'c.community_groups', 'c.public_administration', 'c.labour_organising']}; bad {'content': ['c.military_defence', 'c.wildlife_conservation'], 'form': ['c.military_defence', 'c.taxation_compliance']}

## cal.m06 (multi): Neighbours clear a fallen tree from the road after a storm and share a meal afterwards

- content, variant 0: `c.road_safety` (Road safety and traffic), fit 4; list ['c.disaster_experience', 'c.weather_climate_adaptation', 'c.neighbours_community', 'c.road_safety']
- content, variant 1: `c.road_safety` (Road safety and traffic), fit 4; list ['c.disaster_experience', 'c.neighbours_community', 'c.weather_climate_adaptation', 'c.road_safety']
- form, variant 0: `c.eating_drinking` (Eating and drinking), fit 4; list ['c.mutual_aid', 'c.hospitality_hosting', 'c.eating_drinking']
- outcome, variant 0: `c.disaster_experience` (Disasters and emergencies), fit 5; list ['c.road_safety', 'c.disaster_experience', 'c.mutual_aid']
- outcome, variant 1: `c.disaster_experience` (Disasters and emergencies), fit 5; list ['c.road_safety', 'c.disaster_experience']
- gold fair {'content': ['c.neighbours_community', 'c.mutual_aid', 'c.weather_climate_adaptation', 'c.public_safety_emergency', 'c.eating_drinking', 'c.disaster_experience', 'c.socialising'], 'form': ['c.mutual_aid', 'c.neighbours_community', 'c.volunteering', 'c.hospitality_hosting', 'c.socialising'], 'outcome': ['c.public_safety_emergency', 'c.road_safety', 'c.neighbours_community', 'c.mutual_aid']}; bad {'content': ['c.policing_enforcement', 'c.wildlife_conservation'], 'form': ['c.policing_enforcement', 'c.environmental_stewardship']}

## cal.m07 (multi): A student nurse sits her licensing exam after two years of vocational training

- form, variant 0: `c.healthcare_work` (Healthcare professions), fit 4; list ['c.exams_assessment', 'c.vocational_training', 'c.healthcare_work']
- form, variant 1: `c.healthcare_work` (Healthcare professions), fit 4; list ['c.exams_assessment', 'c.vocational_training', 'c.healthcare_work']
- gold fair {'content': ['c.vocational_training', 'c.healthcare_work', 'c.medical_care', 'c.exams_assessment', 'c.higher_education'], 'form': ['c.exams_assessment', 'c.vocational_training'], 'outcome': ['c.vocational_training', 'c.healthcare_work', 'c.employment_transition', 'c.exams_assessment']}; bad {'content': ['c.academic_dishonesty', 'c.mental_health'], 'form': ['c.academic_dishonesty', 'c.mental_health']}

## cal.m09 (multi): A journalist interviews flood survivors at a shelter and files the story for the evening paper

- content, variant 0: `s.transitions` (Life events and transitions), fit 6; list ['c.disaster_experience', 's.transitions', 'c.news_media']
- gold fair {'content': ['c.disaster_experience', 'c.weather_climate_adaptation', 'c.public_safety_emergency', 'c.news_media', 'c.journalism'], 'form': ['c.journalism', 'c.news_media', 'c.media_publishing'], 'setting': ['c.public_safety_emergency', 'c.disaster_experience', 'c.journalism', 'c.news_media']}; bad {'content': ['c.political_discourse', 'c.misinformation_defamation'], 'form': ['c.political_discourse', 'c.misinformation_defamation']}

## cal.m10 (multi): A choir sings at a wedding in the village church

- setting, variant 0: `s.meaning` (Belief, meaning and ethics), fit 7; list ['c.religion_worship', 's.meaning']
- gold fair {'content': ['c.marriage_wedding', 'c.music_making', 'c.celebrations', 'c.religion_worship', 'c.rites_of_passage', 'c.family_rituals', 'c.religious_community'], 'form': ['c.music_making', 'c.performing_arts', 'c.religion_worship'], 'setting': ['c.religious_community', 'c.religion_worship', 'c.celebrations', 'c.neighbours_community']}; bad {'content': ['c.festivals_events', 'c.nightlife'], 'form': ['c.festivals_events', 'c.nightlife']}

## cal.m11 (multi): A small-shop owner repays a bank loan and hires a part-time assistant

- form, variant 1: `c.job_search` (Job search and hiring), fit 4; list ['c.borrowing_debt', 'c.entrepreneurship', 'c.banking_payments', 'c.job_search']
- gold fair {'content': ['c.borrowing_debt', 'c.entrepreneurship', 'c.employment_job', 'c.retail_work', 'c.banking_payments', 'c.income_earning'], 'form': ['c.borrowing_debt', 'c.banking_payments', 'c.entrepreneurship', 'c.employment_job'], 'outcome': ['c.employment_job', 'c.entrepreneurship', 'c.borrowing_debt', 'c.income_earning']}; bad {'content': ['c.taxation_compliance', 'c.insurance_risk'], 'form': ['c.taxation_compliance', 'c.saving_investing']}

## cal.m12 (multi): A woman is diagnosed with diabetes and starts a new diet and a walking routine

- form, variant 0: `c.walking_cycling` (Walking and cycling), fit 7; list ['c.nutrition_diet', 'c.walking_cycling', 'c.exercise_fitness', 'c.medical_care']
- form, variant 1: `c.walking_cycling` (Walking and cycling), fit 5; list ['c.nutrition_diet', 'c.exercise_fitness', 'c.medical_care', 'c.walking_cycling']
- gold fair {'content': ['c.serious_illness', 'c.physical_health', 'c.medical_care', 'c.nutrition_diet', 'c.exercise_fitness', 'c.walking_cycling'], 'form': ['c.medical_care', 'c.nutrition_diet', 'c.exercise_fitness', 'c.serious_illness'], 'outcome': ['c.physical_health', 'c.nutrition_diet', 'c.exercise_fitness']}; bad {'content': ['c.alternative_medicine', 'c.mental_health'], 'form': ['c.alternative_medicine', 'c.medication_adherence']}

## cal.s01 (single): A woman sleeps through the night in her own bed

- form, variant 0: `s.self_care` (Body, health and self-care), fit 6; list ['c.sleep', 's.self_care']
- gold fair {'content': ['c.sleep'], 'form': ['c.sleep'], 'setting': ['c.home_organisation']}; bad {'content': ['c.mental_health', 'c.physical_health'], 'form': ['c.mental_health', 'c.physical_health', 'c.nutrition_diet']}

## cal.s02 (single): A girl washes her hands with soap before lunch

- form, variant 0: `s.self_care` (Body, health and self-care), fit 6; list ['c.hygiene_grooming', 's.self_care']
- gold fair {'content': ['c.hygiene_grooming', 'c.preventive_health'], 'form': ['c.hygiene_grooming']}; bad {'content': ['c.eating_drinking', 'c.cooking'], 'form': ['c.eating_drinking', 'c.cooking', 'c.medical_care']}

## cal.s03 (single): A boy walks the family dog around the block

- content, variant 0: `c.family_ties` (Family relations), fit 5; list ['c.pet_ownership', 'c.family_ties']
- form, variant 1: `c.exercise_fitness` (Exercise and fitness), fit 4; list ['c.walking_cycling', 'c.pet_ownership', 'c.exercise_fitness']
- gold fair {'content': ['c.pet_ownership', 'c.walking_cycling'], 'form': ['c.pet_ownership', 'c.walking_cycling']}; bad {'content': ['c.animal_care_husbandry', 'c.wildlife_conservation'], 'form': ['c.animal_care_husbandry', 'c.wildlife_conservation', 'c.sport_participation']}

## cal.s04 (single): A woman casts her ballot at the polling station

- content, variant 0: `s.public` (Governance, law and public life), fit 7; list ['c.voting_elections', 's.public']
- form, variant 0: `c.political_participation` (Political participation), fit 6; list ['c.voting_elections', 'c.political_participation']
- form, variant 1: `c.political_participation` (Political participation), fit 6; list ['c.voting_elections', 'c.political_participation']
- setting, variant 1: `c.public_administration` (Public administration and policy), fit 5; list ['c.voting_elections', 'c.public_administration']
- setting, variant 0: `s.public` (Governance, law and public life), fit 7; list ['c.voting_elections', 's.public']
- gold fair {'content': ['c.voting_elections', 'c.political_participation'], 'form': ['c.voting_elections'], 'setting': ['c.voting_elections', 'c.political_participation']}; bad {'content': ['c.political_discourse', 'c.legal_system'], 'form': ['c.political_discourse', 'c.government_services', 'c.legal_system']}

## cal.s05 (single): A man folds the laundry he took off the line

- form, variant 0: `s.home` (Home and household), fit 6; list ['c.cleaning_laundry', 's.home']
- gold fair {'content': ['c.cleaning_laundry', 'c.clothing_footwear'], 'form': ['c.cleaning_laundry']}; bad {'content': ['c.waste_recycling', 'c.home_energy_utilities'], 'form': ['c.waste_recycling', 'c.home_energy_utilities']}

## cal.s06 (single): A teenager plays a video game on a console

- content, variant 0: `c.digital_tool_use` (Everyday digital tool use), fit 4; list ['c.video_gaming', 's.leisure', 'c.digital_tool_use']
- content, variant 1: `c.youth_culture` (Youth and peer culture), fit 4; list ['c.video_gaming', 'c.youth_culture']
- content, variant 0: `s.leisure` (Play, arts, sport and media), fit 7; list ['c.video_gaming', 's.leisure', 'c.digital_tool_use']
- gold fair {'content': ['c.video_gaming', 'c.games_play'], 'form': ['c.video_gaming', 'c.games_play']}; bad {'content': ['c.gambling', 'c.computer_science', 'c.software_development'], 'form': ['c.gambling', 'c.social_media', 'c.computer_science', 'c.software_development']}

## cal.s07 (single): A woman sits in a pew during the Sunday service

- content, variant 1: `c.religious_community` (Religious community and clergy), fit 5; list ['c.religion_worship', 'c.religious_community']
- content, variant 0: `s.meaning` (Belief, meaning and ethics), fit 8; list ['c.religion_worship', 's.meaning']
- form, variant 0: `c.religious_community` (Religious community and clergy), fit 5; list ['c.religion_worship', 'c.religious_community']
- form, variant 1: `c.religious_community` (Religious community and clergy), fit 5; list ['c.religion_worship', 'c.religious_community']
- setting, variant 0: `s.meaning` (Belief, meaning and ethics), fit 7; list ['c.religious_community', 's.meaning', 'c.religion_worship']
- gold fair {'content': ['c.religion_worship', 'c.spirituality'], 'form': ['c.religion_worship'], 'setting': ['c.religious_community', 'c.religion_worship']}; bad {'content': ['c.family_rituals', 'c.rites_of_passage'], 'form': ['c.community_groups', 'c.family_rituals', 'c.rites_of_passage']}

## cal.s08 (single): A commuter rides the bus to work

- content, variant 0: `c.employment_job` (Having a job), fit 4; list ['c.commuting', 'c.public_transport', 'c.employment_job']
- content, variant 1: `c.employment_job` (Having a job), fit 5; list ['c.commuting', 'c.public_transport', 'c.employment_job']
- gold fair {'content': ['c.public_transport', 'c.commuting'], 'form': ['c.public_transport', 'c.commuting']}; bad {'content': ['c.driving', 'c.road_safety'], 'form': ['c.employment_job', 'c.driving', 'c.road_safety']}

## cal.s09 (single): A man mows the lawn behind his house

- form, variant 0: `s.home` (Home and household), fit 5; list ['c.household_gardening', 's.home']
- setting, variant 0: `c.household_gardening` (Home gardening), fit 7; list ['s.home', 'c.household_gardening']
- gold fair {'content': ['c.household_gardening'], 'form': ['c.household_gardening'], 'setting': ['c.home_organisation']}; bad {'content': ['c.horticulture_farming', 'c.environmental_stewardship'], 'form': ['c.horticulture_farming', 'c.environmental_stewardship', 'c.exercise_fitness']}

## cal.s10 (single): A girl reads a picture book in bed

- content, variant 0: `c.basic_skills` (Literacy, numeracy and basic skills), fit 5; list ['c.reading', 'c.basic_skills', 'c.children_play']
- form, variant 0: `c.children_play` (Children's play), fit 4; list ['c.reading', 'c.children_play']
- gold fair {'content': ['c.reading', 'c.children_play'], 'form': ['c.reading']}; bad {'content': ['c.sleep', 'c.early_childhood_education'], 'form': ['c.sleep', 'c.early_childhood_education', 'c.creative_writing']}

## cal.s11 (single): A woman pays her electricity bill online

- form, variant 1: `c.household_budgeting` (Household budgeting), fit 5; list ['c.banking_payments', 'c.digital_tool_use', 'c.household_budgeting']
- form, variant 0: `c.household_planning` (Household management), fit 7; list ['c.banking_payments', 'c.household_planning', 'c.online_commerce']
- form, variant 0: `c.online_commerce` (Online shopping and platforms), fit 6; list ['c.banking_payments', 'c.household_planning', 'c.online_commerce']
- gold fair {'content': ['c.home_energy_utilities', 'c.household_budgeting', 'c.banking_payments'], 'form': ['c.banking_payments', 'c.digital_tool_use']}; bad {'content': ['c.rent_mortgage', 'c.taxation_compliance', 'c.energy_systems'], 'form': ['c.rent_mortgage', 'c.taxation_compliance', 'c.subscriptions_telecom']}

## cal.s12 (single): A man runs five kilometres in the park

- content, variant 0: `c.outdoor_recreation` (Outdoor recreation), fit 4; list ['c.exercise_fitness', 'c.sport_participation', 'c.outdoor_recreation']
- content, variant 1: `c.outdoor_recreation` (Outdoor recreation), fit 4; list ['c.exercise_fitness', 'c.sport_participation', 'c.outdoor_recreation']
- setting, variant 0: `s.nature` (Nature, animals and environment), fit 7; list ['c.outdoor_recreation', 's.nature']
- gold fair {'content': ['c.exercise_fitness', 'c.sport_participation'], 'form': ['c.exercise_fitness', 'c.sport_participation'], 'setting': ['c.outdoor_recreation']}; bad {'content': ['c.sport_spectating', 'c.nutrition_diet'], 'form': ['c.sport_spectating', 'c.nutrition_diet', 'c.tourism_travel']}

