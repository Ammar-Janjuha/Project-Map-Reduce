#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <mpi.h>

#define MAX_WORDS 5000      // Per process limit
#define MAX_WORD_LEN 100
#define MAX_FILES 10

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

// Map function: Process a file and return local word counts
int map_function(const char *filename, WordCount *local_counts) {
    FILE *file = fopen(filename, "r");
    if (!file) {
        return 0;
    }
    
    char word[MAX_WORD_LEN];
    int local_unique = 0;
    
    while (fscanf(file, "%99s", word) == 1) {
        // Clean the word
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
            
            // Check if word exists in local counts
            int found = 0;
            for(int i = 0; i < local_unique; i++) {
                if(strcmp(local_counts[i].word, clean_word) == 0) {
                    local_counts[i].count++;
                    found = 1;
                    break;
                }
            }
            
            // Add new word
            if(!found && local_unique < MAX_WORDS) {
                strcpy(local_counts[local_unique].word, clean_word);
                local_counts[local_unique].count = 1;
                local_unique++;
            }
        }
    }
    
    fclose(file);
    return local_unique;
}

// Function to compare word counts for sorting
int compare_word_counts(const void *a, const void *b) {
    WordCount *wc1 = (WordCount *)a;
    WordCount *wc2 = (WordCount *)b;
    
    if(wc2->count != wc1->count) {
        return wc2->count - wc1->count;
    }
    return strcmp(wc1->word, wc2->word);
}

// Function to merge two sorted word count arrays
int merge_word_counts(WordCount *arr1, int size1, WordCount *arr2, int size2, WordCount *result) {
    int i = 0, j = 0, k = 0;
    
    while(i < size1 && j < size2 && k < MAX_WORDS) {
        if(arr1[i].count > arr2[j].count) {
            result[k++] = arr1[i++];
        } else if(arr1[i].count < arr2[j].count) {
            result[k++] = arr2[j++];
        } else {
            // Equal counts, sort alphabetically
            if(strcmp(arr1[i].word, arr2[j].word) < 0) {
                result[k++] = arr1[i++];
            } else {
                result[k++] = arr2[j++];
            }
        }
    }
    
    while(i < size1 && k < MAX_WORDS) {
        result[k++] = arr1[i++];
    }
    
    while(j < size2 && k < MAX_WORDS) {
        result[k++] = arr2[j++];
    }
    
    return k;
}

int main(int argc, char *argv[]) {
    int rank, size;
    double start_time, end_time;
    
    // Initialize MPI
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    // Check command line arguments
    if(argc < 2 && rank == 0) {
        printf("Usage: mpirun -np <num_processes> %s <file1> [file2 ...]\n", argv[0]);
        printf("Example: mpirun -np 4 %s input1.txt input2.txt input3.txt\n", argv[0]);
        MPI_Finalize();
        return 1;
    }
    
    // Start timing (only root process)
    if(rank == 0) {
        start_time = MPI_Wtime();
        printf("=== PARALLEL MAPREDUCE WORD COUNT ===\n");
        printf("Number of processes: %d\n", size);
        printf("Number of files: %d\n", argc - 1);
    }
    
    // Broadcast number of files to all processes
    int num_files = argc - 1;
    MPI_Bcast(&num_files, 1, MPI_INT, 0, MPI_COMM_WORLD);
    
    // Broadcast filenames to all processes
    char filenames[MAX_FILES][256];
    if(rank == 0) {
        for(int i = 0; i < num_files; i++) {
            strcpy(filenames[i], argv[i + 1]);
        }
    }
    
    for(int i = 0; i < num_files; i++) {
        MPI_Bcast(filenames[i], 256, MPI_CHAR, 0, MPI_COMM_WORLD);
    }
    
    // ========== MAP PHASE ==========
    WordCount local_counts[MAX_WORDS];
    int local_unique = 0;
    
    // Distribute files among processes (simple round-robin)
    for(int i = rank; i < num_files; i += size) {
        if(i < num_files) {
            printf("Process %d processing file: %s\n", rank, filenames[i]);
            int new_words = map_function(filenames[i], &local_counts[local_unique]);
            local_unique += new_words;
        }
    }
    
    // Sort local results
    qsort(local_counts, local_unique, sizeof(WordCount), compare_word_counts);
    
    // ========== SHUFFLE & REDUCE PHASE ==========
    // We'll use a tree-based reduction for efficiency
    
    int step = 1;
    while(step < size) {
        if(rank % (2 * step) == 0) {
            // Receiver process
            int sender = rank + step;
            if(sender < size) {
                // Receive size from sender
                int sender_unique;
                MPI_Recv(&sender_unique, 1, MPI_INT, sender, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                
                // Receive data from sender
                WordCount received_counts[MAX_WORDS];
                MPI_Recv(received_counts, sender_unique * sizeof(WordCount), MPI_CHAR, 
                        sender, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                
                // Merge with local counts
                WordCount merged_counts[MAX_WORDS];
                int merged_size = merge_word_counts(local_counts, local_unique, 
                                                   received_counts, sender_unique, 
                                                   merged_counts);
                
                // Copy merged results back to local_counts
                memcpy(local_counts, merged_counts, merged_size * sizeof(WordCount));
                local_unique = merged_size;
            }
        } else if(rank % (2 * step) == step) {
            // Sender process
            int receiver = rank - step;
            
            // Send size first
            MPI_Send(&local_unique, 1, MPI_INT, receiver, 0, MPI_COMM_WORLD);
            
            // Send data
            MPI_Send(local_counts, local_unique * sizeof(WordCount), MPI_CHAR, 
                    receiver, 0, MPI_COMM_WORLD);
            break;  // This process is done
        }
        step *= 2;
    }
    
    // ========== FINAL OUTPUT (Root Process) ==========
    if(rank == 0) {
        end_time = MPI_Wtime();
        double execution_time = end_time - start_time;
        
        printf("\n=== PARALLEL WORD COUNT RESULTS ===\n");
        printf("Total processes: %d\n", size);
        printf("Total files processed: %d\n", num_files);
        printf("Unique words found: %d\n", local_unique);
        printf("Parallel execution time: %.4f seconds\n", execution_time);
        
        printf("\n=== TOP 20 WORDS ===\n");
        printf("%-20s %s\n", "WORD", "COUNT");
        printf("%-20s %s\n", "----", "-----");
        
        int print_limit = (local_unique > 20) ? 20 : local_unique;
        for(int i = 0; i < print_limit; i++) {
            printf("%-20s %d\n", local_counts[i].word, local_counts[i].count);
        }
        
        // Save results to file
        FILE *output = fopen("parallel_results.txt", "w");
        if(output) {
            fprintf(output, "Processes: %d\n", size);
            fprintf(output, "Files: %d\n", num_files);
            fprintf(output, "Unique words: %d\n", local_unique);
            fprintf(output, "Time: %.4f seconds\n\n", execution_time);
            fprintf(output, "Word Frequency Table:\n");
            fprintf(output, "%-20s %s\n", "WORD", "COUNT");
            for(int i = 0; i < local_unique; i++) {
                fprintf(output, "%-20s %d\n", local_counts[i].word, local_counts[i].count);
            }
            fclose(output);
            printf("\nResults saved to 'parallel_results.txt'\n");
        }
        
        // Read serial time if available for comparison
        FILE *serial_file = fopen("serial_results.txt", "r");
        if(serial_file) {
            char line[256];
            double serial_time = 0;
            while(fgets(line, sizeof(line), serial_file)) {
                if(strstr(line, "Time:")) {
                    sscanf(line, "Time: %lf seconds", &serial_time);
                    break;
                }
            }
            fclose(serial_file);
            
            if(serial_time > 0) {
                double speedup = serial_time / execution_time;
                double efficiency = (speedup / size) * 100;
                
                printf("\n=== PERFORMANCE ANALYSIS ===\n");
                printf("Serial execution time: %.4f seconds\n", serial_time);
                printf("Parallel execution time: %.4f seconds\n", execution_time);
                printf("Speedup: %.2fx\n", speedup);
                printf("Efficiency: %.1f%%\n", efficiency);
                
                // Save performance analysis
                FILE *perf = fopen("performance.txt", "w");
                if(perf) {
                    fprintf(perf, "Number of Processes: %d\n", size);
                    fprintf(perf, "Serial Time: %.4f seconds\n", serial_time);
                    fprintf(perf, "Parallel Time: %.4f seconds\n", execution_time);
                    fprintf(perf, "Speedup: %.2f\n", speedup);
                    fprintf(perf, "Efficiency: %.1f%%\n", efficiency);
                    fclose(perf);
                }
            }
        }
    }
    
    MPI_Finalize();
    return 0;
}