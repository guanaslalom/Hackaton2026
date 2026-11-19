import { LightningElement, api } from 'lwc';
import getLeaderboard from '@salesforce/apex/MemoryGameController.getLeaderboard';
import { errorMessage, formatTime } from 'c/memoryGameEngine';

const TOP_N = 50;
const TOP_10_SIZE = 10;

/**
 * Per-game leaderboard with Top 10, Top 50, and the current player's rank.
 */
export default class MemoryLeaderboard extends LightningElement {
    @api gameId;

    isLoading = true;
    loadError;
    leaderboard;
    activeTab = 'top10';

    connectedCallback() {
        this.load();
    }

    async load() {
        this.isLoading = true;
        this.loadError = undefined;
        try {
            this.leaderboard = JSON.parse(await getLeaderboard({ gameId: this.gameId, topN: TOP_N }));
        } catch (error) {
            this.loadError = errorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    get entries() {
        if (!this.leaderboard) {
            return [];
        }
        if (this.activeTab === 'top10') {
            return this.leaderboard.topEntries.slice(0, TOP_10_SIZE);
        }
        if (this.activeTab === 'top50') {
            return this.leaderboard.topEntries;
        }
        return this.leaderboard.myEntry ? [this.leaderboard.myEntry] : [];
    }

    get rows() {
        return this.entries.map((entry, index) => ({
            key: `${this.activeTab}-${index}-${entry.rank}`,
            rank: entry.rank,
            displayName: entry.displayName,
            score: entry.score,
            time: formatTime(entry.durationSeconds),
            moves: entry.moves,
            rowClass: entry.isCurrentPlayer ? 'slds-hint-parent slds-theme_shade' : 'slds-hint-parent'
        }));
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get emptyMessage() {
        if (this.activeTab === 'mine') {
            return 'Complete a game to appear on the leaderboard.';
        }
        return 'No completed games yet.';
    }

    handleTabActive(event) {
        this.activeTab = event.target.value;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }
}
