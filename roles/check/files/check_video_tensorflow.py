import torch
import tensorflow as tf

print('=' * 60)
print('PyTorch:')
print(f'  Version: {torch.__version__}')
print(f'  CUDA: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  GPU: {torch.cuda.get_device_name(0)}')

print('\nTensorFlow:')
print(f'  Version: {tf.__version__}')
gpus = tf.config.list_physical_devices('GPU')
print(f'  GPU: {len(gpus)} device(s)')
if gpus:
    print(f'  Name: {gpus[0].name}')

print('=' * 60)

# PyTorch test
if torch.cuda.is_available():
    x = torch.randn(100, 100).cuda()
    y = x @ x
    print('✅ PyTorch GPU works')

# TensorFlow test
if gpus:
    with tf.device('/GPU:0'):
        x = tf.random.normal([100, 100])
        y = tf.matmul(x, x)
    print('✅ TensorFlow GPU works')
