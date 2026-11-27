# Disputed gold-judge verdicts (membership gold v1)

20 (item, relation, domain) triples were judged differently by the two variants, or `unsure` by one. They are left out of the gold's `fair` and `bad` lists (recorded as `unsure`) until ruled. Rule by adding `{"item", "relation", "domain", "verdict": "fair"|"bad"}` lines to `data/gold/membership_wide_rulings_v1.jsonl`.

## cal.d01: A baker named Mason sells bread at the market

- form `c.entrepreneurship` (Entrepreneurship and small business): variant 0 fair: A baker selling bread at the market is self-employed trading, a real secondary form of the act; variant 1 unsure: A baker selling bread at a market could be self-employed, but the text does not say he runs a business, so a careful reader could go either way
## cal.d02: A woman buys a train ticket on a bank holiday

- form `c.retail_shopping` (Retail shopping): variant 0 unsure: Buying a train ticket is a purchase but not clearly buying goods in shops; a careful reader could go either way; variant 1 bad: A train ticket is a service purchase; the text does not place it in a shop or market, so buying goods in shops is an extra assumption
- form `s.consumption` (Consumption, money and property): variant 0 fair: Buying a ticket is an act of consumption, a real aspect of the event's form; variant 1 bad: Consumption is a domain the purchase is about, offered here as the kind of act; buying a ticket is the act itself
## cal.d03: A woman reads a recipe for tiger prawns

- content `c.eating_drinking` (Eating and drinking): variant 0 fair: A recipe for tiger prawns engages food and eating as its object domain, though secondary to cooking; variant 1 bad: A recipe is read for cooking; eating and drinking are not engaged by the text
## cal.d07: A cashier at a petrol station counts the day's takings

- content `s.consumption` (Consumption, money and property): variant 0 unsure: Counting takings engages money handling, but the consumption domain (buying, saving, income) fits only loosely; variant 1 fair: Counting the day's takings is handling money from sales, a real secondary aspect of the event's content
## cal.m01: A hospital nurse works a night shift on the maternity ward

- content `s.transitions` (Life events and transitions): variant 0 bad: The nurse's night shift is work; birth is only the ward's setting, not what the shift is about; variant 1 fair: A maternity ward shift engages births, a life transition, as its subject matter
## cal.m02: A village family grows maize and sells the surplus at the weekly market

- form `c.sales_marketing` (Sales, marketing and advertising): variant 0 unsure: Selling surplus is a sale, but the text shows no marketing or promotion; a careful reader could go either way; variant 1 fair: Selling the surplus at the market is the act of sales
- setting `c.horticulture_farming` (Crop farming and horticulture): variant 0 fair: Growing maize on a family farm places the event in the farming sphere; variant 1 bad: The text gives a market as the place of the event; horticulture is the activity grown, not the sphere or venue
## cal.m03: A mother teaches her daughter to knit while they listen to the radio

- content `c.parenting_young_children` (Parenting young children): variant 0 unsure: Teaching a daughter to knit is parenting, but the text gives no age to place her as a young child; variant 1 unsure: A mother teaching her daughter to knit engages parenting, but the daughter's age is not given, so young-children parenting cannot be confirmed
## cal.m06: Neighbours clear a fallen tree from the road after a storm and share a meal afterwards

- outcome `c.disaster_experience` (Disasters and emergencies): variant 0 bad: The observable change is a cleared road; the disaster itself is not changed by the event; variant 1 fair: The road is cleared where the storm left it blocked, an observable change in the aftermath
## cal.m11: A small-shop owner repays a bank loan and hires a part-time assistant

- form `c.job_search` (Job search and hiring): variant 0 unsure: Repaying a loan is the main act; hiring is a secondary act and a careful reader could go either way on whether it counts as recruiting; variant 1 fair: Hiring a part-time assistant is a recruiting act, a real secondary aspect of the event
## cal.s04: A woman casts her ballot at the polling station

- form `c.political_participation` (Political participation): variant 0 fair: Voting is a form of political participation in the broad sense of the category; variant 1 unsure: Voting is a form of political participation, but the broader domain may be read as the act's category or as a different relation; a careful reader could go either way
- setting `c.public_administration` (Public administration and policy): variant 0 unsure: A polling station is an electoral venue run by administration; a careful reader could go either way on whether administration is its sphere; variant 1 bad: A polling station is an electoral venue; public administration is not the sphere the text names
## cal.s06: A teenager plays a video game on a console

- form `c.digital_tool_use` (Everyday digital tool use): variant 0 unsure: Console play uses a device, but the domain is generic device use and the text does not show digital tool use as the act; a careful reader could go either way; variant 1 bad: The act is playing a game on a console; digital tool use names the device category, while the fitting form is video gaming.
## cal.s08: A commuter rides the bus to work

- content `c.employment_job` (Having a job): variant 0 bad: The bus ride is the subject; work is only the destination in the text, so employment as content needs an assumption; variant 1 unsure: Commuting is the event and work is only the stated destination ('to work'); a careful reader could accept or reject paid work as a content aspect.
- content `s.work` (Work, trades and enterprise): variant 0 bad: The bus ride to work is about commuting; work is only the destination in the text, so the work domain needs an assumption; variant 1 unsure: Same as the commuting case: the bus ride is the event and work is the destination the text names; the broader work domain makes it a closer call.
## cal.s09: A man mows the lawn behind his house

- form `s.home` (Home and household): variant 0 unsure: Mowing is yard upkeep that fits household work as an activity kind, but a careful reader could read the sphere as content rather than the form of the act; variant 1 unsure: Mowing is household upkeep, but the domain names a sphere; a careful reader could take either reading of the act.
## cal.s10: A girl reads a picture book in bed

- content `c.basic_skills` (Literacy, numeracy and basic skills): variant 0 unsure: Reading a picture book may engage early literacy, but the text shows reading for enjoyment, not literacy skills being learned; a careful reader could go either way; variant 1 unsure: Picture-book reading may be early literacy, but the text shows reading for pleasure in bed, not skill-building.
## cal.s12: A man runs five kilometres in the park

- content `c.outdoor_recreation` (Outdoor recreation): variant 0 unsure: Running five kilometres in a park is exercise; outdoor recreation such as hiking is at best a secondary fit, and a careful reader could go either way; variant 1 bad: Running five kilometres in a park is exercise; calling it outdoor recreation needs an assumed recreational purpose the text does not give.
- setting `s.nature` (Nature, animals and environment): variant 0 unsure: A park is a green space, but the text gives no nature, farming or conservation content; a careful reader could take a park as nature or as public recreation space; variant 1 unsure: A park is a green space a reader could place under nature, but the text names only the park, not nature or conservation.
