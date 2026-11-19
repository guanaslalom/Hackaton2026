// Seeds one active 8-pair Memory Matching Game with 16 cards.
// Run once per org: re-running creates another game, so deactivate or delete the old one first.
Game__c game = new Game__c(
    Name = 'Memory Matching Game',
    Description__c = 'Find all matching pairs in as few moves and as little time as possible.',
    Is_Active__c = true,
    Number_of_Pairs__c = 8,
    Maximum_Time__c = 0,
    Base_Score__c = 1000,
    Move_Penalty__c = 10,
    Time_Penalty__c = 2,
    Time_Penalty_Interval_Seconds__c = 5,
    Completion_Bonus__c = 100
);
insert game;

List<String> symbols = new List<String>{ '🍎', '🚀', '🎸', '🌵', '🐙', '🎲', '🍩', '🔭' };
List<Game_Card__c> cards = new List<Game_Card__c>();
for (Integer i = 0; i < symbols.size(); i++) {
    for (Integer copy = 1; copy <= 2; copy++) {
            cards.add(new Game_Card__c(
            Name = 'P' + (i + 1) + '-' + copy,
            Game__c = game.Id,
            Pair_Identifier__c = 'P' + (i + 1),
            Display_Symbol__c = symbols[i],
            Is_Active__c = true
        ));
    }
}
insert cards;

System.debug('Seeded game ' + game.Id + ' with ' + cards.size() + ' cards.');
