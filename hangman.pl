use strict;
use warnings;
use JSON;  # To encode and decode JSON files for saving/loading game state
use Term::ANSIColor;  # To colorize output in the terminal
use List::Util qw(shuffle);  # To shuffle a list of words (if needed)
use File::Slurp;  # For reading and writing files easily
use Term::ReadKey;  # To control input behavior (e.g., turning off echoing for password-like input)

# Constants
my $MAX_ATTEMPTS = 6;  # The maximum number of incorrect guesses allowed
my $SAVE_FILE = "hangman_save.json";  # File where the saved game state is stored
my $SCORES_FILE = "scores.json";  # File where player scores are stored
my @WORDS = qw(energy flower pandora trousers glasses luxury subway);  # List of words for the game

# Data structure for the game state
# Stores information like player names, the current word, guessed letters, attempts left, and scores
my %game_state = (
    player1 => '',  # Name of player 1
    player2 => '',  # Name of player 2 (used in multiplayer mode)
    current_word => '',  # The word to guess
    guessed_letters => [],  # List of guessed letters
    remaining_attempts => $MAX_ATTEMPTS,  # Number of attempts left before the game is lost
    scores => {},  # Holds the scores for each player
);

# Main menu: allows the player to choose between starting a new game, continuing a saved game, viewing the scoreboard, or quitting
sub main_menu {
    print colored("Welcome to Hangman Game!\n", 'bold cyan');  # Display the welcome message in cyan color
    print "1. Start New Game\n";
    print "2. Continue Saved Game\n";
    print "3. View Scoreboard\n";
    print "4. Exit\n";
    print "Choose an option: ";
    my $choice = <STDIN>;  # Get user input
    chomp $choice;  # Remove the newline at the end

    # Based on the user's choice, either start a new game, load a saved game, view scores, or exit
    if ($choice == 1) {
        start_new_game();
    } elsif ($choice == 2) {
        load_game();
    } elsif ($choice == 3) {
        view_scoreboard();
    } elsif ($choice == 4) {
        exit;
    } else {
        print "Invalid choice. Try again.\n";
        main_menu();
    }
}

sub start_new_game {
    # Reset the game state to start fresh, clearing player names, guessed letters, and remaining attempts.
    $game_state{player1} = '';  # Clear player 1's name
    $game_state{player2} = '';  # Clear player 2's name (if multiplayer)
    $game_state{guessed_letters} = [];  # Clear the list of guessed letters
    $game_state{remaining_attempts} = $MAX_ATTEMPTS;  # Set remaining attempts to the maximum allowed

    # Prompt the user to choose the game mode: 1 for Single Player or 2 for Multiplayer
    print "Choose mode: 1. Single Player  2. Multiplayer\n";
    my $mode = <STDIN>;  # Capture the user's input
    chomp $mode;  # Remove the newline character from the input

    # Single Player Mode
    if ($mode == 1) {
        print "Enter your name: ";  # Prompt for player 1's name
        $game_state{player1} = <STDIN>;  # Store player 1's name
        chomp $game_state{player1};  # Remove the newline character
        # Randomly select a word for the player to guess
        $game_state{current_word} = $WORDS[ rand @WORDS ];
        play_game();  # Call the play_game function to start the game

    # Multiplayer Mode
    } elsif ($mode == 2) {
        print "Player 1, enter your name: ";  # Prompt for player 1's name
        $game_state{player1} = <STDIN>;  # Store player 1's name
        chomp $game_state{player1};  # Remove the newline character
        print "Player 2, enter your name: ";  # Prompt for player 2's name
        $game_state{player2} = <STDIN>;  # Store player 2's name
        chomp $game_state{player2};  # Remove the newline character
        # Prompt player 1 to enter a word for player 2 to guess, with hidden input
        print "Player 1, enter the word for Player 2 to guess: ";
        ReadMode('noecho');  # Disable input echoing to hide the word
        $game_state{current_word} = <STDIN>;  # Store the word to be guessed
        ReadMode('restore'); # Restore normal input echoing
        chomp $game_state{current_word};  # Remove the newline character
        print "\n";  # Print a newline for clean formatting
        play_game();  # Call the play_game function to start the game

    # Invalid Mode Input
    } else {
        print "Invalid mode.\n";  # Inform the user if the mode input is invalid
        start_new_game();  # Recursively call start_new_game to prompt for a valid mode
    }
}

sub display_hangman {
    my $attempts = shift;  # The remaining attempts (passed as argument)

    # An array of hangman figures, each corresponding to a different number of attempts
    my @hangman = (
        qq{
          +---+
              |
              |
              |
             ===
        },                # 0 attempts: the starting state, no parts drawn
        qq{
          +---+
          O   |
              |
              |
             ===
        },          # 1 attempt: head added
        qq{
          +---+
          O   |
          |   |
              |
             ===
        },   # 2 attempts: body added
        qq{
          +---+
          O   |
         /|   |
              |
             ===
        },  # 3 attempts: left arm added
        qq{
          +---+
          O   |
         /|\\  |
              |
             ===
        },  # 4 attempts: right arm added
        qq{
          +---+
          O   |
         /|\\  |
         /    |
             ===
        },  # 5 attempts: left leg added
        qq{
          +---+
          O   |
         /|\\  |
         / \\  |
             ===
        },  # 6 attempts: right leg added (final state)
    );

    # Prevent going out of bounds by ensuring that the index is between 0 and 6
    my $index = $MAX_ATTEMPTS - $attempts;
    $index = 0 if $index < 0;  # If the attempts exceed the maximum, use the first figure (no parts)
    
    # Print the current hangman figure based on the number of attempts
    print "$hangman[$index]\n";
}

# Function to generate the hangman state based on remaining attempts
sub get_hangman_state {
    my $attempts = shift;  # The number of remaining attempts passed as argument
    
    # Array of hangman figures for each state of the game, corresponding to the number of attempts
    my @hangman = (
        qq{
          +---+
              |
              |
              |
             ===
        },                # 0 attempts: the starting state, no parts drawn
        qq{
          +---+
          O   |
              |
              |
             ===
        },          # 1 attempt: head added
        qq{
          +---+
          O   |
          |   |
              |
             ===
        },   # 2 attempts: body added
        qq{
          +---+
          O   |
         /|   |
              |
             ===
        },  # 3 attempts: left arm added
        qq{
          +---+
          O   |
         /|\\  |
              |
             ===
        },  # 4 attempts: right arm added
        qq{
          +---+
          O   |
         /|\\  |
         /    |
             ===
        },  # 5 attempts: left leg added
        qq{
          +---+
          O   |
         /|\\  |
         / \\  |
             ===
        },  # 6 attempts: right leg added (full hangman)
    );

    # Calculate the index based on remaining attempts and ensure it doesn't go out of bounds
    my $index = $MAX_ATTEMPTS - $attempts;  # Subtract attempts from maximum to get the correct index
    $index = 0 if $index < 0;  # If attempts exceed the maximum, set index to 0 (starting state)

    # Return the current hangman state based on the number of attempts left
    return $hangman[$index];
}