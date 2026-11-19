/**
 * Tests for MemoryGameService: scoring, session lifecycle, server-side replay validation,
 * player isolation, and leaderboard ranking.
 *
 * @author Slalom
 */
@IsTest
private class MemoryGameServiceTest {

    @TestSetup
    static void makeData() {
        Game__c game = new Game__c(
            Name = 'Test Game',
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

        List<Game_Card__c> cards = new List<Game_Card__c>();
        for (Integer i = 1; i <= 8; i++) {
            for (Integer copy = 1; copy <= 2; copy++) {
                cards.add(new Game_Card__c(
                    Name = 'P' + i + '-' + copy,
                    Game__c = game.Id,
                    Pair_Identifier__c = 'P' + i,
                    Display_Symbol__c = 'S' + i,
                    Is_Active__c = true
                ));
            }
        }
        insert cards;

        insert new List<Contact>{
            new Contact(FirstName = 'Ada', LastName = 'Player'),
            new Contact(FirstName = 'Ben', LastName = 'Rival'),
            new Contact(FirstName = 'Cy', LastName = 'Third')
        };
    }

    @IsTest
    static void calculatesScoreForReferenceGame() {
        MemoryGameService.ScoringRules rules = new MemoryGameService.ScoringRules();
        rules.basePoints = 1000;
        rules.movePenalty = 10;
        rules.timePenalty = 2;
        rules.intervalSeconds = 5;
        rules.completionBonus = 100;

        MemoryGameService.ScoreBreakdown score = MemoryGameService.calculateScore(rules, 8, 20, 90);

        Assert.areEqual(12, score.extraMoves, 'Moves beyond the pair count');
        Assert.areEqual(18, score.intervalsElapsed, '90 seconds in 5-second intervals');
        Assert.areEqual(944, score.finalScore, 'Expected 1000 - 120 - 36 + 100');
    }

    @IsTest
    static void submitScoresAWinningReplayOnTheServer() {
        Id playerId = contactNamed('Player');
        MemoryGameService.Board board = MemoryGameService.startSession(playerId, gameId());

        Test.startTest();
        MemoryGameService.SubmitResult result = MemoryGameService.submitSession(
            playerId, board.sessionId, winningAttempts(board.sessionId), 0
        );
        Test.stopTest();

        Assert.areEqual('Completed', result.status);
        Assert.areEqual(8, result.matchedPairs);
        Assert.areEqual(1100, result.score.finalScore, 'No extra moves and no elapsed time');
        Game_Session__c session = [SELECT Status__c, Final_Score__c FROM Game_Session__c WHERE Id = :board.sessionId];
        Assert.areEqual('Completed', session.Status__c);
        Assert.areEqual(1100, session.Final_Score__c);
    }

    @IsTest
    static void rejectsIncompleteAndInvalidReplays() {
        Id playerId = contactNamed('Player');
        MemoryGameService.Board board = MemoryGameService.startSession(playerId, gameId());

        try {
            MemoryGameService.submitSession(playerId, board.sessionId, JSON.serialize(new List<MemoryGameService.Attempt>{ flip(0, 1) }), 0);
            Assert.fail('An incomplete game should be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Not all pairs'), e.getMessage());
        }

        try {
            MemoryGameService.submitSession(playerId, board.sessionId, JSON.serialize(new List<MemoryGameService.Attempt>{ flip(3, 3) }), 0);
            Assert.fail('Flipping the same card twice should be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Invalid card selection'), e.getMessage());
        }

        MemoryGameService.SubmitResult result = MemoryGameService.submitSession(
            playerId, board.sessionId, winningAttempts(board.sessionId), 0
        );
        Assert.areEqual('Completed', result.status, 'A rejected submit should leave the session open');
    }

    @IsTest
    static void rejectsDuplicateSubmit() {
        Id playerId = contactNamed('Player');
        MemoryGameService.Board board = MemoryGameService.startSession(playerId, gameId());
        String attempts = winningAttempts(board.sessionId);
        MemoryGameService.submitSession(playerId, board.sessionId, attempts, 0);

        try {
            MemoryGameService.submitSession(playerId, board.sessionId, attempts, 0);
            Assert.fail('A completed session should not accept a second submit');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('already been submitted'), e.getMessage());
        }
    }

    @IsTest
    static void rejectsDurationBeyondElapsedTime() {
        Id playerId = contactNamed('Player');
        MemoryGameService.Board board = MemoryGameService.startSession(playerId, gameId());

        try {
            MemoryGameService.submitSession(playerId, board.sessionId, winningAttempts(board.sessionId), 60);
            Assert.fail('A duration far beyond the elapsed time should be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('longer than the time since the game started'), e.getMessage());
        }
    }

    @IsTest
    static void abandonsSessionWhenTimeLimitIsExceeded() {
        update new Game__c(Id = gameId(), Maximum_Time__c = 5);
        Id playerId = contactNamed('Player');
        MemoryGameService.Board board = MemoryGameService.startSession(playerId, gameId());

        MemoryGameService.SubmitResult result = MemoryGameService.submitSession(
            playerId, board.sessionId, winningAttempts(board.sessionId), 6
        );

        Assert.areEqual('Abandoned', result.status);
        Game_Session__c session = [SELECT Status__c, Final_Score__c FROM Game_Session__c WHERE Id = :board.sessionId];
        Assert.areEqual('Abandoned', session.Status__c);
        Assert.areEqual(0, session.Final_Score__c);
    }

    @IsTest
    static void otherPlayersCannotAbandonASession() {
        Id owner = contactNamed('Player');
        Id rival = contactNamed('Rival');
        MemoryGameService.Board board = MemoryGameService.startSession(owner, gameId());

        try {
            MemoryGameService.abandonSession(rival, board.sessionId);
            Assert.fail('Another player should not reach this session');
        } catch (AuraHandledException e) {
            Assert.areEqual('Game session not found.', e.getMessage());
        }
        Assert.areEqual('In Progress', [SELECT Status__c FROM Game_Session__c WHERE Id = :board.sessionId].Status__c);
    }

    @IsTest
    static void startingAgainAbandonsTheOpenSession() {
        Id playerId = contactNamed('Player');
        MemoryGameService.Board first = MemoryGameService.startSession(playerId, gameId());
        MemoryGameService.Board second = MemoryGameService.startSession(playerId, gameId());

        Assert.areEqual('Abandoned', [SELECT Status__c FROM Game_Session__c WHERE Id = :first.sessionId].Status__c);
        Assert.areEqual('In Progress', [SELECT Status__c FROM Game_Session__c WHERE Id = :second.sessionId].Status__c);
    }

    @IsTest
    static void resolveRejectsUserWithoutContact() {
        Profile standard = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueName = 'memgame' + DateTime.now().getTime() + '@example.com';
        User noContact = new User(
            Alias = 'mgtest',
            Email = uniqueName,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Tester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standard.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = uniqueName
        );
        insert noContact;

        System.runAs(noContact) {
            try {
                MemoryGameService.resolveCurrentContactId();
                Assert.fail('A user without a contact should be rejected');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('not linked to a contact'), e.getMessage());
            }
        }
    }

    @IsTest
    static void leaderboardRanksTiedScoresTogether() {
        Id gameId = gameId();
        insert new List<Game_Session__c>{
            completedSession(gameId, contactNamed('Player'), 1000),
            completedSession(gameId, contactNamed('Rival'), 800),
            completedSession(gameId, contactNamed('Third'), 800)
        };

        MemoryLeaderboardService.Leaderboard board = MemoryLeaderboardService.getLeaderboard(gameId, contactNamed('Rival'), 10);

        Assert.areEqual(3, board.totalPlayers);
        Assert.areEqual(1, board.topEntries[0].rank);
        Assert.areEqual(2, board.topEntries[1].rank);
        Assert.areEqual(2, board.topEntries[2].rank, 'Equal scores share a rank');
        Assert.areEqual(2, board.myEntry.rank, 'Caller rank');
        Assert.isTrue(board.myEntry.isCurrentPlayer);
    }

    @IsTest
    static void controllerReturnsActiveGamesAndRequiresAContact() {
        Assert.areEqual(1, MemoryGameController.getActiveGames().size(), 'Only the seeded active game');

        try {
            MemoryGameController.getLeaderboard(gameId(), 5);
            Assert.fail('The admin test user has no contact');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('not linked to a contact'), e.getMessage());
        }
    }

    private static Id gameId() {
        return [SELECT Id FROM Game__c LIMIT 1].Id;
    }

    private static Id contactNamed(String lastName) {
        return [SELECT Id FROM Contact WHERE LastName = :lastName LIMIT 1].Id;
    }

    private static MemoryGameService.Attempt flip(Integer first, Integer second) {
        MemoryGameService.Attempt attempt = new MemoryGameService.Attempt();
        attempt.first = first;
        attempt.second = second;
        return attempt;
    }

    private static Game_Session__c completedSession(Id gameId, Id playerId, Integer score) {
        return new Game_Session__c(
            Game__c = gameId,
            Player__c = playerId,
            Status__c = 'Completed',
            Start_Date__c = System.now(),
            Completion_Date__c = System.now(),
            Final_Score__c = score,
            Duration_Seconds__c = 60,
            Total_Moves__c = 8,
            Matched_Pairs__c = 8
        );
    }

    /**
     * Builds a winning attempts payload from the stored layout by flipping each matching pair in turn.
     * Card_Layout__c is server-only, so the test reads it as the running admin user.
     */
    private static String winningAttempts(Id sessionId) {
        String rawLayout = [SELECT Card_Layout__c FROM Game_Session__c WHERE Id = :sessionId].Card_Layout__c;
        List<String> layout = (List<String>) JSON.deserialize(rawLayout, List<String>.class);

        List<MemoryGameService.Attempt> attempts = new List<MemoryGameService.Attempt>();
        Map<String, Integer> firstPositionByKey = new Map<String, Integer>();
        for (Integer position = 0; position < layout.size(); position++) {
            String key = layout[position];
            if (firstPositionByKey.containsKey(key)) {
                attempts.add(flip(firstPositionByKey.get(key), position));
            } else {
                firstPositionByKey.put(key, position);
            }
        }
        return JSON.serialize(attempts);
    }
}
