import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveGames from '@salesforce/apex/MemoryGameController.getActiveGames';
import getPlayerStats from '@salesforce/apex/MemoryGameController.getPlayerStats';
import startSession from '@salesforce/apex/MemoryGameController.startSession';
import submitSession from '@salesforce/apex/MemoryGameController.submitSession';
import abandonSession from '@salesforce/apex/MemoryGameController.abandonSession';
import { errorMessage } from 'c/memoryGameEngine';

const VIEW = {
    LOADING: 'loading',
    HOME: 'home',
    PLAYING: 'playing',
    COMPLETE: 'complete',
    LEADERBOARD: 'leaderboard'
};

/**
 * Container for the Memory Matching Game in Experience Cloud. Owns the view state and every Apex
 * call. Child components only raise events.
 */
export default class MemoryGameApp extends LightningElement {
    view = VIEW.LOADING;
    games = [];
    selectedGameId;
    stats;
    currentGameId;
    board;
    result;
    previousBest = null;
    leaderboardGameId;
    busy = false;

    connectedCallback() {
        this.initialize();
    }

    get isLoading() {
        return this.view === VIEW.LOADING;
    }

    get isHome() {
        return this.view === VIEW.HOME;
    }

    get isPlaying() {
        return this.view === VIEW.PLAYING;
    }

    get isComplete() {
        return this.view === VIEW.COMPLETE;
    }

    get isLeaderboard() {
        return this.view === VIEW.LEADERBOARD;
    }

    async initialize() {
        try {
            this.games = await getActiveGames();
            if (this.games.length > 0) {
                this.selectedGameId = this.games[0].Id;
                await this.refreshStats();
            }
        } catch (error) {
            this.showError(error);
        }
        this.view = VIEW.HOME;
    }

    async refreshStats() {
        if (!this.selectedGameId) {
            this.stats = undefined;
            return;
        }
        try {
            this.stats = JSON.parse(await getPlayerStats({ gameId: this.selectedGameId }));
        } catch (error) {
            this.showError(error);
        }
    }

    async handleSelectGame(event) {
        this.selectedGameId = event.detail.gameId;
        this.busy = true;
        await this.refreshStats();
        this.busy = false;
    }

    handleStart(event) {
        this.startGame(event.detail.gameId);
    }

    handleRestart(event) {
        this.startGame(event.detail.gameId);
    }

    handlePlayAgain() {
        this.startGame(this.currentGameId);
    }

    async startGame(gameId) {
        this.busy = true;
        try {
            const stats = JSON.parse(await getPlayerStats({ gameId }));
            this.previousBest = stats.personalBest ?? null;
            this.board = JSON.parse(await startSession({ gameId }));
            this.currentGameId = gameId;
            this.selectedGameId = gameId;
            this.result = undefined;
            this.view = VIEW.PLAYING;
        } catch (error) {
            this.showError(error);
        } finally {
            this.busy = false;
        }
    }

    async handleGameFinished(event) {
        const { sessionId, attempts, durationSeconds } = event.detail;
        this.busy = true;
        try {
            this.result = JSON.parse(await submitSession({
                sessionId,
                attemptsJson: JSON.stringify(attempts),
                durationSeconds
            }));
            this.view = VIEW.COMPLETE;
        } catch (error) {
            this.showError(error);
            this.view = VIEW.HOME;
        } finally {
            this.board = undefined;
            await this.refreshStats();
            this.busy = false;
        }
    }

    async handleExit(event) {
        this.busy = true;
        try {
            await abandonSession({ sessionId: event.detail.sessionId });
        } catch (error) {
            this.showError(error);
        }
        this.board = undefined;
        this.view = VIEW.HOME;
        await this.refreshStats();
        this.busy = false;
    }

    handleHome() {
        this.result = undefined;
        this.view = VIEW.HOME;
        this.refreshStats();
    }

    handleLeaderboard(event) {
        this.leaderboardGameId = event.detail.gameId;
        this.view = VIEW.LEADERBOARD;
    }

    showError(error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Something went wrong',
                message: errorMessage(error),
                variant: 'error'
            })
        );
    }
}
