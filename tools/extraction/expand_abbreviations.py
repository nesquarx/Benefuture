import re
import json

pseudocode_path = "/Users/arko.sen/Desktop/BfTest/Bf_Pseudocode.txt"
with open(pseudocode_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Extract all explicit «...» pairs
explicit_abbrs = re.findall(r'([A-Za-z0-9_]+)\s*«\s*([^»]+)\s*»', text)

# Map abbreviation -> expanded name
abbr_to_expanded = {}
expanded_to_abbr = {}

for name, abbr in explicit_abbrs:
    abbr_clean = abbr.strip()
    name_clean = name.strip()
    abbr_to_expanded[abbr_clean] = name_clean
    expanded_to_abbr[name_clean] = abbr_clean

# Additional well-known mathematical shorthand symbols defined in pseudocode:
symbol_expansions = {
    'ℝ': 'Reality',
    '𝕌': 'Universe',
    'T': 'Thing / Things',
    'E': 'Entity / Entities',
    'B': 'Being / Beings',
    'Pe': 'Person / Persons',
    'S': 'Sophont / Sophonts',
    'So': 'Society',
    'M': 'Marker / Markers',
    'C': 'Currency / Currencies',
    'A': 'Action / Actions',
    'O': 'Outcome / Outcomes',
    'D': 'Decision / Decisions',
    'I': 'Interaction / Interactions',
    'Ou': 'Outputs',
    'In': 'Intent',
    'Ct': 'Contract',
    'Tx': 'Transaction',
    'Po': 'Power',
    'Inf': 'Influence',
    'Imp': 'Impact',
    'G': 'Goal',
    'Gd': 'Good',
    'Bd': 'Bad',
    'H': 'Happiness',
    'Ha': 'Harm',
    'NHa': 'NecessaryHarm',
    'N': 'Novelty',
    'Di': 'Diversity',
    'Sy': 'Synergy',
    'Ŝy': 'SquashedSynergy',
    'Sl': 'Self',
    'Mr': 'Morality',
    'St': 'Sentience',
    'Se': 'SubjectiveExperience',
    'Th': 'Threshold',
    'Pr': 'Predict / Prediction',
    'PrAcc': 'PredictionAccuracy',
    'CE': 'CausalExplanation',
    'U': 'Understanding',
    'Ml': 'Model',
    'Cy': 'Complexity',
    'Sp': 'Sapience',
    'lt': 'LongTerm',
    't': 'Time',
    'Ig': 'Ignorance',
    'Tr': 'Truth',
    'Tr_lvl': 'TruthLevel',
    'Cx': 'Context',
    'Rlv': 'Relevance',
    'F': 'Fact',
    'Hy': 'Hypothesis',
    'Me': 'Measurement',
    'As': 'Assess / Assessment',
    'MM': 'MetricModel',
    'CorrSc': 'CorrelationScore',
    'Rw': 'Reward',
    'CD': 'CausalDistribution',
    'CC': 'CausalContribution',
    'RA': 'ResourceAccounting',
    'PE': 'ProbabilisticEscrow',
    'TP': 'TransactionProposal',
    'CNet': 'CurrencyNetwork',
    'Re': 'Reputation',
    'Bal': 'Balance',
    'BalOvflw': 'BalanceOverflow',
    'Lw': 'Law',
    'Cv': 'Civilization',
    'CG': 'CollectiveGoals',
    'Af': 'AntiFragility',
    'Ad': 'Administration',
    'Gv': 'Governance',
    'Dm': 'Democracy',
    'VW': 'VoteWeight',
    'BfDm': 'BenefutureDemocracy',
    'LqdBfDm': 'LiquidBenefutureDemocracy',
    'Cr': 'Crime',
    'J': 'Justice',
    'EHR': 'ExternalHarmResponse',
    'Lia': 'Liability',
    'En': 'Enforcement',
    'Aco': 'Accolade',
    'Fork': 'Fork',
    'Merge': 'Merge',
    'Cu': 'Culture',
    'Art': 'Art',
    'IHz': 'InfoHazard',
    'CrT': 'CriticalThinking',
    'Ed': 'Education',
    'EQ': 'EmotionalIntelligence',
    'SN': 'SocialNetwork',
    'TN': 'TechNetwork',
    'BTS': 'BehavioralTxnSubstrate',
    'Mem': 'Memory',
    'Fr': 'Freedom',
    'Ec': 'Economy',
    'EL': 'EmbeddedLaws',
    'Im': 'Implementation',
    'SO': 'SophontOversight',
    'SB': 'SophontBaselineIncome',
    'Harm_Intv': 'HarmInterventionAxiom',
    'Rc_Innovation': 'ResourceInnovationAxiom',
    'CvCnt': 'CivilizationContinuityAxiom',
    'Prog': 'ProgressiveAxiom',
    'SigThGv': 'SignificanceThresholdGovernance',
    'Di_N_Balance': 'DiversityNoveltyBalanceAxiom',
    'AC': 'AntiCorruption',
    'AdvAp': 'AdversarialAdaptation',
    'Tt': 'Trust',
    'Cn': 'Concerns',
    'Bf': 'Benefuture',
    'Dn': 'Domain',
    'Pm': 'Params',
    'Sig': 'Significant / Significance',
    'Rc': 'Resource',
    'Ap': 'Adapt / Adaptation',
    'Cnt': 'Continuity',
    'V': 'Value'
}

for k, v in symbol_expansions.items():
    if k not in abbr_to_expanded:
        abbr_to_expanded[k] = v

print(f"Total unified abbreviations/symbols: {len(abbr_to_expanded)}")

with open("/Users/arko.sen/.gemini/antigravity-ide/brain/55887d51-9588-406a-8757-9147764d4575/scratch/all_abbreviations.json", "w") as out:
    json.dump(abbr_to_expanded, out, indent=2)
