#!/usr/bin/bash

# Paths to required files
summary_file="summaries.txt"
holistic_summary_file="holistic-summaries.txt"
progress_file="progress.log"
main_dir=$(pwd)

# Ensure progress and summary files exist
touch "$main_dir/$progress_file"
touch "$main_dir/$summary_file"
touch "$main_dir/$holistic_summary_file"

# Extract the "summary of summaries" from summaries.txt
summary_of_summaries=$(grep -A1000 "===== Summaries for" "$summary_file" | tail -n +2)

# Start logging
echo "Starting holistic summarization process at $(date)" >> "$main_dir/$progress_file"

# Iterate over each .txt file in the directory, excluding specified files
for file in "$main_dir"/*.txt; do
    # Skip summaries.txt and holistic-summaries.txt explicitly
    if [[ "$(basename "$file")" == "$(basename "$summary_file")" || "$(basename "$file")" == "$(basename "$holistic_summary_file")" ]]; then
        echo "Skipping $file" >> "$main_dir/$progress_file"
        continue
    fi

    # Process all other .txt files
    if [ -f "$file" ]; then
        file_path=$(realpath "$file")

        # Process only if not processed before
        if ! grep -Fxq "$file_path" "$main_dir/$progress_file"; then
            echo "Processing $file"
            echo "Processing $file" >> "$main_dir/$progress_file"

            # Create a temporary directory for the file's chunks
            sanitized_name=$(basename "$file" | tr -d '[:space:]')
            temp_dir=$(mktemp -d "$main_dir/tmp_${sanitized_name}_XXXXXX")
            echo "Temporary directory created: $temp_dir" >> "$main_dir/$progress_file"

            # Split the file into chunks of 100 lines each
            split -d -l 100 "$file" "$temp_dir/chunk_"
            echo "File split into chunks: $(find "$temp_dir" -type f)" >> "$main_dir/$progress_file"

            # Summarize each chunk with the "summary of summaries" as context
            for chunk_file in "$temp_dir"/chunk_*; do
                [ -f "$chunk_file" ] || continue

                # Read chunk content
                chunk_content=$(cat "$chunk_file")

                # Combine context and chunk
                combined_input="Here is an overall summary of previous summaries:
$summary_of_summaries

Now, summarize this chunk:
$chunk_content"

                # Summarize the chunk and append to holistic-summaries.txt
                echo "Summarizing chunk $(basename "$chunk_file") with additional context"
                echo "$combined_input" | ollama run vanilj/phi-4 | tee -a "$main_dir/$holistic_summary_file"
                echo "" | tee -a "$main_dir/$holistic_summary_file"
            done

            # Remove the temporary directory
            rm -rf "$temp_dir"
            echo "Temporary directory $temp_dir removed" >> "$main_dir/$progress_file"

            # Mark the file as processed
            echo "$file_path" >> "$main_dir/$progress_file"
        fi
    fi
done

echo "Holistic summarization process completed at $(date)" >> "$main_dir/$progress_file"
