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

# Generate the hidden word based on the current guessed letters
sub generate_hidden_word {
    my ($word) = @_;
    my $hidden_word = '';
    
    for my $i (0 .. length($word) - 1) {
        my $letter = substr($word, $i, 1);
        if (grep { $_ eq $letter } @{ $game_state{guessed_letters} }) {
            $hidden_word .= $letter;  # Reveal the letter if guessed
        } else {
            $hidden_word .= '_';  # Otherwise, hide the letter
        }
    }
    
    return $hidden_word;
}

# Function to save the current game state, including the hidden word and remaining attempts
sub save_game {
    my ($hidden_word, $attempts) = @_;  # Arguments: current hidden word and remaining attempts

    # Update the global game state hash with the current game information
    $game_state{hidden_word} = $hidden_word;  # Save the current hidden word
    $game_state{remaining_attempts} = $attempts;  # Save the number of remaining attempts
    $game_state{hangman_state} = get_hangman_state($attempts);  # Get and save the current hangman drawing based on attempts

    # Write the updated game state to a file in JSON format
    write_file($SAVE_FILE, encode_json(\%game_state));  # Save the game state in the file specified by $SAVE_FILE
}

# Function to load a saved game state from a file
sub load_game {
    if (-e $SAVE_FILE) {  # Check if the save file exists
        # Read and decode the JSON file into the %game_state hash
        %game_state = %{ decode_json(read_file($SAVE_FILE)) };

        # If the game is over or already guessed, ask to start a new one
        if ($game_state{remaining_attempts} <= 0 || generate_hidden_word($game_state{current_word}) eq $game_state{current_word}) {
            print "Game over or word already guessed! Starting a new game.\n";
            main_menu(); # Start a fresh game
        } else {
            print "Game loaded successfully! Continuing...\n";
            play_game();  # Continue the game from where it was left off
        }
    } else {
        print "No saved game found.\n";
        main_menu();  # Return to the main menu
    }
}

# Function to update the scoreboard by incrementing the correct player's wins
sub update_scoreboard {
    my ($player) = @_;  # The player whose score needs to be updated
    my $scores = {};    # Initialize an empty hash to store the scores

    # Check if the scoreboard file exists and load the existing scores
    if (-e $SCORES_FILE) {
        # Decode the JSON data from the scoreboard file into the $scores hash
        $scores = decode_json(read_file($SCORES_FILE));
    }

    # If the player doesn't exist in the scoreboard, initialize their score to 0
    # Then increment the player's score by 1
    $scores->{$player} ||= 0;  # Initialize the player's score to 0 if not already present
    $scores->{$player}++;      # Increment the player's score by 1

    # Write the updated scoreboard back to the file
    write_file($SCORES_FILE, encode_json($scores));  # Save the updated scores in JSON format
}

# Function to view the scoreboard, sorted by the number of wins in descending order
sub view_scoreboard {
    if (-e $SCORES_FILE) {  # Check if the scoreboard file exists
        # Decode the JSON data from the scoreboard file into the $scores hash
        my $scores = decode_json(read_file($SCORES_FILE));
        
        print "Scoreboard:\n";  # Print header for the scoreboard

        # Sort the players by their number of wins in descending order
        foreach my $player (sort { $scores->{$b} <=> $scores->{$a} } keys %$scores) {
            # Print the player's name and their win count
            print "$player: $scores->{$player} wins\n";
        }
    } else {
        print "No scores available.\n";  # Inform the user if no scoreboard exists
    }

    main_menu();  # Return to the main menu after displaying the scoreboard
}

# Function to play the Hangman game
sub play_game {
    my $word = $game_state{current_word};  # The word to be guessed
    my $hidden_word = generate_hidden_word($word);  # Initially generate the hidden word (with underscores)
    my $attempts = $game_state{remaining_attempts};  # Number of remaining attempts
    
    # Display the hangman drawing based on the number of remaining attempts
    display_hangman($attempts);

    # Game loop: Continue until there are no attempts left
    while ($attempts > 0) {
        print "\nWord: $hidden_word\n";  # Display the current hidden word (with guessed letters filled in)
        print "Guessed letters: @{ $game_state{guessed_letters} }\n";  # Display guessed letters
        print "Attempts remaining: $attempts\n";  # Display remaining attempts
        print "Enter a letter or type 'save' to save progress: ";  # Prompt user for input
        my $guess = <STDIN>;  # Get the user's guess
        chomp $guess;  # Remove newline character

        # Check if the user wants to save the game
        if ($guess eq 'save') {
            save_game($hidden_word, $attempts);  # Save the current game state
            print "Game progress saved!\n";  # Inform the user that progress has been saved
            main_menu();  # Return to the main menu
            return;  # Exit the function to stop the game
        }

        # Validate the user's input (only a single letter, alphabetic characters)
        if ($guess !~ /^[a-zA-Z]$/ || length($guess) > 1) {
            print "Invalid input. Enter a single letter.\n";  # Inform the user if the input is invalid
            next;  # Skip to the next iteration of the loop
        }

        # Prevent re-guessed letters (check if the letter has already been guessed)
        if (grep { $_ eq $guess } @{ $game_state{guessed_letters} }) {
            print "You've already guessed that letter.\n";  # Inform the user if they've guessed the letter already
            next;  # Skip to the next iteration of the loop
        }

        # Add the guessed letter to the list of guessed letters
        push @{ $game_state{guessed_letters} }, $guess;

        # Check if the guess is correct
        if (index($word, $guess) != -1) {
            print "Correct guess!\n";  # Inform the user if the guess is correct
            # Update the hidden word with the correct guess
            $hidden_word = generate_hidden_word($word);
            print "Updated Word: $hidden_word\n";  # Display the updated word

            # Check if the entire word is guessed correctly
            if ($hidden_word eq $word) {
                print colored("Congratulations! You've guessed the word: $word\n", 'bold green');
                
                # Update the scoreboard with the winner (Player 1 or Player 2)
                if ($game_state{player2}) {
                    # Multiplayer mode - Player 2 wins
                    update_scoreboard($game_state{player2});
                } else {
                    # Single-player mode - Player 1 wins
                    update_scoreboard($game_state{player1});
                }

                save_game($hidden_word, $attempts);  # Save the final game state
                main_menu();  # Return to the main menu after the game ends
                return;  # Exit the function to stop the game
            }
        } else {
            print "Incorrect guess.\n";  # Inform the user if the guess is incorrect
            $attempts--;  # Decrease the remaining attempts
        }

        # Check if the game is over (no attempts left)
        if ($attempts <= 0) {
            print colored("Game Over! The word was: $word\n", 'bold red');  # Inform the user the game is over
            main_menu();  # Return to the main menu after the game ends
            return;  # Exit the function to stop the game
        }

        # Display the hangman drawing after each guess (correct or incorrect)
        display_hangman($attempts); 
    }

    # If the loop ends (game over), display the game over message
    print colored("Game Over! The word was: $word\n", 'bold red');
    main_menu();  # Return to the main menu after the game ends
}

# Call the main menu function to start the game
main_menu();