# Life Image: disputed cases for the author's review (confirming battery v1)

Each case: the item, and where the three runs disagreed. Mark a verdict per line (agree with one run, or give the right answer).

## bd.mp.threat_cash.a (disagreements: 8)
> A man threatens a shopkeeper, who then hands over the till money
- form: Violence and assault | Theft and property crime | Theft and property crime
- outcome: None | Theft and property crime | Theft and property crime
- setting: Consumption, money and property | Retail and wholesale work | None
- shopkeeper contribution [0.0, 0.4, 0.4]
- shopkeeper responsibility [0.0, 1, 1]
- threatener contribution [0.0, 0.6, 0.6]
- threatener responsibility [0.0, 1, 0.5]
- threatener production [None, None, 'consumed']

## bd.mp.decisive_vote.a (disagreements: 7)
> One council member's vote makes a 5 to 4 majority pass the budget
- content: Public administration and policy | Public administration and policy | Economics and finance research
- setting: Governance, law and public life | Public administration and policy | Governance, law and public life
- member_x production [None, None, 'produced']
- no_voters production [None, None, 'produced']
- other_yes contribution [0.3, 0.5, 0.8]
- other_yes responsibility [0.5, 1, 1]
- other_yes production [None, None, 'produced']

## bd.new.volunteers (disagreements: 7)
> Three volunteers lift a fallen tree off a road, and any two of them could have done it without the third
- form: Emergency and rescue services | Helping others informally | Helping others informally
- content: Road safety and traffic | Disasters and emergencies | Weather, climate and adaptation
- outcome: Road safety and traffic | Emergency and rescue services | Emergency and rescue services
- setting: Travel, mobility and place | None | Travel, mobility and place
- volunteer_1 production [None, None, 'produced']
- volunteer_2 production [None, None, 'produced']
- volunteer_3 production [None, None, 'produced']

## bd.new.vote5 (disagreements: 7)
> A village committee of nine votes 5 to 4 to build a footbridge, and the motion needed exactly five votes
- setting: Governance, law and public life | Public administration and policy | Governance, law and public life
- no_voters production [None, None, 'produced']
- yes_1 production [None, None, 'produced']
- yes_2 production [None, None, 'produced']
- yes_3 production [None, None, 'produced']
- yes_4 production [None, None, 'produced']
- yes_5 production [None, None, 'produced']

## bd.new.coercion (disagreements: 6)
> A clerk opens the office safe after a robber holds a knife to her colleague and says he will use it unless she does
- outcome: None | Theft and property crime | Theft and property crime
- setting: Work, trades and enterprise | Office and administrative work | Work, trades and enterprise
- clerk contribution [0.0, 0.4, 0.3]
- clerk responsibility [0.0, 1, 1]
- robber contribution [0.0, 0.6, 0.6]
- robber responsibility [0.0, 1, 1]

## cf.vaccination_flu (disagreements: 6)
> A pharmacist gives a pensioner a flu jab in October, and the pensioner stays well through a winter in which her flatmate, without a jab, is hospitalised with flu
- outcome: Preventive health | Physical health and illness | Preventive health
- setting: Body, health and self-care | Medical care | Medical care
- pensioner responsibility [0.0, 0.5, 0]
- pensioner production ['consumed', 'consumed', None]
- pharmacist contribution [0.8, 0.8, 0.5]
- pharmacist production ['produced', 'produced', None]

## ev.131 (disagreements: 6)
> Forced labour on a fishing boat
- content: Exploitation and trafficking | Exploitation and trafficking | Agricultural, forestry and fishing work
- outcome: None | None | Exploitation and trafficking
- setting: Work, trades and enterprise | Agricultural, forestry and fishing work | Work, trades and enterprise
- operator contribution [0.0, 0, 0.9]
- operator responsibility [0.0, 0, 1]
- workers production [None, None, 'produced']

## bd.mp.donation_coerced.b (disagreements: 5)
> A man hands money to a charity after being threatened
- outcome: None | Charity and giving | None
- donor contribution [0.0, 0.4, 0]
- donor responsibility [0.0, 1, 0]
- threatener contribution [0.0, 0.6, 0]
- threatener responsibility [0.0, 1, 0]

## bd.new.ghostwriter (disagreements: 5)
> A ghostwriter writes a memoir that a retired footballer publishes under his own name
- form: Media, publishing and creative professions | Media, publishing and creative professions | Creative writing
- content: Creative writing | Creative writing | Media, publishing and creative professions
- footballer production [None, 'produced', 'produced']
- ghostwriter production [None, 'produced', 'produced']
- publisher production [None, 'produced', 'produced']

## bd.rt.55 (disagreements: 5)
> LLM hallucinated citation used by a lawyer
- form: Law and courts | Legal profession | Legal profession
- content: Law and courts | Artificial intelligence and machine learning | Artificial intelligence and machine learning
- setting: None | Law and courts | None
- lawyer production [None, 'consumed', 'consumed']
- llm production [None, 'produced', 'produced']

## cf.rescue_kayak (disagreements: 4)
> Two kayakers pull a capsized teenager from a cold lake within a minute, and the teenager, who would have drowned within minutes otherwise, walks home wrapped in a blanket
- outcome: Accidents and injuries | Physical health and illness | Accidents and injuries
- kayakers responsibility [0.5, 1, 1]
- kayakers production [None, 'produced', None]
- teenager production [None, 'consumed', None]

## cf.snow_path (disagreements: 4)
> A neighbour clears an elderly woman's snow-covered path before dawn, so she reaches her dialysis appointment, which she would have missed otherwise
- form: Helping others informally | Neighbours and local community | Helping others informally
- content: Helping others informally | Care of the ill or disabled | Care of the ill or disabled
- outcome: Physical health and illness | Medical care | Medical care
- woman production [None, 'consumed', None]

## cf.surgery_appendix (disagreements: 4)
> A surgeon removes a patient's inflamed appendix, which without the operation would have burst within a day, and the patient goes home after three days
- content: Medical care | Medical care | Physical health and illness
- setting: None | Medical care | Medical care
- patient production [None, 'consumed', None]
- surgeon production [None, 'produced', None]

## cf.surgery_recovery (disagreements: 4)
> A surgeon replaces a patient's worn hip, and the patient, who could not walk to the door before the operation, walks the length of the street within two months
- content: Physical health and illness | Disability and adaptation | Physical health and illness
- setting: None | Medical care | Medical care
- patient production [None, 'consumed', None]
- surgeon production [None, 'produced', None]

## cf.transfusion (disagreements: 4)
> A nurse starts a blood transfusion for a mother bleeding after childbirth, and she is sitting up and talking by evening, when without the blood she would not have survived the night
- content: Childbirth and having a baby | Pregnancy and prenatal care | Childbirth and having a baby
- setting: None | Medical care | Medical care
- mother production [None, 'consumed', None]
- nurse production [None, 'produced', None]

## cf.vaccination_outbreak (disagreements: 4)
> A clinic vaccinates 40 schoolchildren against measles while an outbreak spreads through the district, and none of them falls ill, whereas a third of their unvaccinated cousins do
- content: Preventive health | Preventive health | Public health and epidemiology
- setting: Body, health and self-care | Medical care | Medical care
- vaccinated responsibility [0.0, 0.5, 0]
- vaccinated production ['consumed', 'consumed', None]

## cp.watch_review.b (disagreements: 4)
> A man reviews a new documentary about glaciers and the local paper prints his review
- outcome: None | None | News and information media
- readers production [None, 'consumed', 'consumed']
- reviewer contribution [0.0, 0, 0.6]
- reviewer responsibility [0.0, 0, 1]

## ev.20 (disagreements: 4)
> Spending weekends caring for a father with dementia
- content: Care of older people | Care of older people | Care of the ill or disabled
- setting: None | Family, intimacy and care | None
- carer production [None, 'produced', None]
- father production [None, 'consumed', 'consumed']

## bd.mp.decisive_vote.b (disagreements: 3)
> A council passes the same budget by 9 to 0
- setting: Governance, law and public life | Public administration and policy | Governance, law and public life
- member_x production [None, None, 'produced']
- other_yes production [None, None, 'produced']

## bd.mp.surgery_assault.b (disagreements: 3)
> A stranger cuts open a man's abdomen with a knife
- outcome: None | Physical health and illness | None
- agent contribution [0.0, 0.9, 0]
- agent responsibility [0.0, 1, 0]

## bd.mp.threat_cash.b (disagreements: 3)
> A shopkeeper hands over the till money
- form: Retail and wholesale work | Retail and wholesale work | Theft and property crime
- content: Banking and payments | Retail and wholesale work | Theft and property crime
- setting: Consumption, money and property | Retail and wholesale work | None

## cf.cooling (disagreements: 3)
> An engineer repairs a data centre's cooling system before a heatwave, and the centre keeps running, whereas a rival's unrepaired centre goes offline for a day
- form: Electrical and energy engineering | Electrical and energy engineering | Mechanical engineering
- setting: Technology, engineering and making | Technology, engineering and making | Work, trades and enterprise
- customers production [None, 'consumed', None]

## cf.petition_ignored (disagreements: 3)
> Residents sign a petition for a pedestrian crossing, and the council builds the crossing it had already planned and would have built without the petition
- form: Political participation | Advocacy and civil society | Political participation
- setting: Travel, mobility and place | Governance, law and public life | Travel, mobility and place
- residents production [None, None, 'produced']

## cf.road_salt (disagreements: 3)
> A council salts the roads before a freezing night, and no crashes are reported on the salted roads, whereas an unsalted lane records three
- form: Urban planning and infrastructure | Public administration and policy | Public administration and policy
- outcome: Road safety and traffic | Accidents and injuries | Road safety and traffic
- drivers production [None, 'consumed', None]

## cf.sandbags (disagreements: 3)
> Volunteers stack sandbags along a street before the river peaks, and the houses behind the bags stay dry, whereas the houses in the next street, without bags, are flooded
- form: Emergency and rescue services | Emergency and rescue services | Helping others informally
- setting: Home and household | Home and household | Travel, mobility and place
- residents production [None, 'consumed', None]

## cf.storm_embankment (disagreements: 3)
> A rail crew reinforces an embankment the week before a storm, and the line stays open while the neighbouring unreinforced line floods and closes for ten days
- content: Disasters and emergencies | Weather, climate and adaptation | Disasters and emergencies
- outcome: Commuting | Commuting | Public transport
- passengers production [None, 'consumed', None]

## cf.storm_roof (disagreements: 3)
> A homeowner replaces loose roof tiles a week before a storm, and the house stays dry whereas the identical house next door, with its loose tiles, floods the loft
- content: Disasters and emergencies | Weather, climate and adaptation | Weather, climate and adaptation
- outcome: Disasters and emergencies | Disasters and emergencies | Weather, climate and adaptation
- homeowner production ['produced', None, None]

## cf.tutoring (disagreements: 3)
> A teacher gives a struggling pupil extra tutoring for a term, and the pupil's marks rise from 40 to 70 percent while the class's other struggling pupils stay flat
- content: School education | Teaching and tutoring | School education
- pupil responsibility [0.0, 0.5, 0]
- pupil production [None, 'consumed', None]

## cp.attend_teach.b (disagreements: 3)
> A teacher gives a maths lesson on fractions to her pupils
- form: Teaching and tutoring | Teaching profession | Teaching and tutoring
- setting: Learning and education | School education | None
- pupils production [None, 'consumed', 'consumed']

## cp.cross_build.b (disagreements: 3)
> A crew builds a new footbridge for commuters to reach the station
- form: Construction and building trades | Civil engineering and construction design | Civil engineering and construction design
- content: Urban planning and infrastructure | Civil engineering and construction design | Urban planning and infrastructure
- commuters production [None, 'consumed', 'consumed']

## Round-trip misses not listed above
- bd.mp.acting_for.a: An employee signs a supply contract on behalf of her company
- bd.new.archers: Five archers on a wall loose arrows at one raider at the same instant, and any one arrow alone would have killed him
- bd.rt.59: Inventor of antibiotics: contribution to events 100 years later
- cf.rescue_mountain_failed: Mountain rescuers climb through the night to a stranded hiker, but he has died of exposure before they arrive, and he would have died even had they set out an hour earlier
- cp.buy_bake.b: A baker bakes the loaves that the corner bakery sells
- cp.read_annotate.b: A student annotates a chapter of a physics textbook and shares her notes with the class
- ev.6: Going to the clinic for a persistent cough
- rt.3: Citizen does not vote in an election