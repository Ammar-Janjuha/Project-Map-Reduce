#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

#define MAX_WORDS 10000
#define MAX_WORD_LEN 100

typedef struct {
    char word[MAX_WORD_LEN];
    int count;
} WordCount;

// Function to convert string to lowercase
void to_lower_case(char *str) {
    for(int i = 0; str[i]; i++) {
        str[i] = tolower(str[i]);
    }
}

// Function to check if character is valid for a word
int is_word_char(char c) {
    return isalnum(c) || c == '\'';
}

// Function to count words in a single file
int count_words_in_file(const char *filename, WordCount *word_counts, int *unique_count) {
    FILE *file = fopen(filename, "r");
    if (!file) {
        printf("Error: Cannot open file %s\n", filename);
        return 0;
    }
    
    char word[MAX_WORD_LEN];
    int total_words = 0;
    
    while (fscanf(file, "%99s", word) == 1) {
        // Clean the word: remove punctuation and convert to lowercase
        char clean_word[MAX_WORD_LEN];
        int j = 0;
        
        for(int i = 0; word[i] && j < MAX_WORD_LEN-1; i++) {
            if(is_word_char(word[i])) {
                clean_word[j++] = word[i];
            }
        }
        clean_word[j] = '\0';
        
        if(strlen(clean_word) > 0) {
            to_lower_case(clean_word);
            total_words++;
            
            // Check if word already exists
            int found = 0;
            for(int i = 0; i < *unique_count; i++) {
                if(strcmp(word_counts[i].word, clean_word) == 0) {
                    word_counts[i].count++;
                    found = 1;
                    break;
                }
            }
            
            // Add new word if not found
            if(!found && *unique_count < MAX_WORDS) {
                strcpy(word_counts[*unique_count].word, clean_word);
                word_counts[*unique_count].count = 1;
                (*unique_count)++;
            }
        }
    }
    
    fclose(file);
    return total_words;
}

// Function to compare word counts for sorting
int compare_word_counts(const void *a, const void *b) {
    WordCount *wc1 = (WordCount *)a;
    WordCount *wc2 = (WordCount *)b;
    
    // Sort by count (descending), then alphabetically
    if(wc2->count != wc1->count) {
        return wc2->count - wc1->count;
    }
    return strcmp(wc1->word, wc2->word);
}

int main(int argc, char *argv[]) {
    if(argc < 2) {
        printf("Usage: %s <file1> [file2 ...]\n", argv[0]);
        printf("Example: %s input1.txt input2.txt\n", argv[0]);
        return 1;
    }
    
    // Start timing
    clock_t start_time = clock();
    
    WordCount word_counts[MAX_WORDS];
    int unique_words = 0;
    int total_words_processed = 0;
    
    // Process each file
    for(int file_idx = 1; file_idx < argc; file_idx++) {
        printf("Processing file: %s\n", argv[file_idx]);
        int words_in_file = count_words_in_file(argv[file_idx], word_counts, &unique_words);
        total_words_processed += words_in_file;
        printf("  Found %d words in this file\n", words_in_file);
    }
    
    // Sort the results
    qsort(word_counts, unique_words, sizeof(WordCount), compare_word_counts);
    
    // Calculate execution time
    clock_t end_time = clock();
    double execution_time = (double)(end_time - start_time) / CLOCKS_PER_SEC;
    
    // Print results
    printf("\n=== SERIAL WORD COUNT RESULTS ===\n");
    printf("Total files processed: %d\n", argc - 1);
    printf("Total words processed: %d\n", total_words_processed);
    printf("Unique words found: %d\n", unique_words);
    printf("Execution time: %.4f seconds\n", execution_time);
    printf("\n=== WORD FREQUENCY TABLE ===\n");
    printf("%-20s %s\n", "WORD", "COUNT");
    printf("%-20s %s\n", "----", "-----");
    
    // Print top 20 words or all if less than 20
    int print_limit = (unique_words > 20) ? 20 : unique_words;
    for(int i = 0; i < print_limit; i++) {
        printf("%-20s %d\n", word_counts[i].word, word_counts[i].count);
    }
    
    if(unique_words > 20) {
        printf("... and %d more words\n", unique_words - 20);
    }
    
    // Save results to file
    FILE *output = fopen("serial_results.txt", "w");
    if(output) {
        fprintf(output, "Total words: %d\n", total_words_processed);
        fprintf(output, "Unique words: %d\n", unique_words);
        fprintf(output, "Time: %.4f seconds\n\n", execution_time);
        fprintf(output, "Word Frequency Table:\n");
        fprintf(output, "%-20s %s\n", "WORD", "COUNT");
        for(int i = 0; i < unique_words; i++) {
            fprintf(output, "%-20s %d\n", word_counts[i].word, word_counts[i].count);
        }
        fclose(output);
        printf("\nResults saved to 'serial_results.txt'\n");
    }
    
    return 0;
}