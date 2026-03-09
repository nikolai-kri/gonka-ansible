import torch
print('=' * 60)
print('PyTorch version:', torch.__version__)
print('CUDA version:', torch.version.cuda)
print('CUDA available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('GPU:', torch.cuda.get_device_name(0))
    print('GPU memory:', f'{torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB')
    print('CUDA Capability:', torch.cuda.get_device_capability(0))
print('=' * 60)
