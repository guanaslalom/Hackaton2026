import { LightningElement, api } from 'lwc';
import { formatTime } from 'c/memoryGameEngine';

/**
 * Landing screen: game choice, how-to-play copy, the player's stats for the selected game, and
 * entry points to start a game or open the leaderboard.
 */
export default class MemoryGameHome extends LightningElement {
    @api games = [];
    @api selectedGameId;
    @api stats;

    get hasNoGames() {
        return this.games.length === 0;
    }

    get hasMultipleGames() {
        return this.games.length > 1;
    }

    get gameOptions() {
        return this.games.map((game) => ({ label: game.Name, value: game.Id }));
    }

    get selectedGame() {
        return this.games.find((game) => game.Id === this.selectedGameId);
    }

    get hasSelectedGame() {
        return Boolean(this.selectedGame);
    }

    get selectedGameView() {
        const game = this.selectedGame;
        if (!game) {
            return {};
        }
        return {
            name: game.Name,
            description: game.Description__c || '',
            pairsLabel: `${game.Number_of_Pairs__c} pairs`,
            timeLabel: game.Maximum_Time__c > 0 ? `Time limit ${formatTime(game.Maximum_Time__c)}` : 'No time limit'
        };
    }

    get gamesPlayed() {
        return this.stats ? this.stats.gamesPlayed : 0;
    }

    get gamesCompleted() {
        return this.stats ? this.stats.gamesCompleted : 0;
    }

    get personalBestDisplay() {
        return this.stats && this.stats.personalBest !== null && this.stats.personalBest !== undefined
            ? `${this.stats.personalBest}`
            : '—';
    }

    handleGameChange(event) {
        this.dispatchEvent(new CustomEvent('selectgame', { detail: { gameId: event.detail.value } }));
    }

    handleStart() {
        this.dispatchEvent(new CustomEvent('start', { detail: { gameId: this.selectedGameId } }));
    }

    handleLeaderboard() {
        this.dispatchEvent(new CustomEvent('leaderboard', { detail: { gameId: this.selectedGameId } }));
    }
}
