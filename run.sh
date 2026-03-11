ROCBLAS_USE_HIPBLASLT=1 \
LD_LIBRARY_PATH="$PWD/target/lib:$LD_LIBRARY_PATH" \
./target/bin/llama-server \
  -m "$PWD/models/Qwen3.5-35B-A3B-Q4_K_M.gguf" \
  -ngl 999 -c 131072 --parallel 1 --no-warmup \
  --temp 0.80 --top-p 0.90 --top-k 30 --min-p 0.00 \
  --repeat-penalty 1.05 --repeat-last-n 256 --flash-attn on\
  --chat-template-kwargs "{\"enable_thinking\": false}" \
  --host 0.0.0.0 --port 8000