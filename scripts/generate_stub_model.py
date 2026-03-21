"""Generate a stub DumplingClassifier.mlmodel for development.

This script produces a valid CoreML image classifier with 9 classes.
The model accepts 224x224 RGB images and outputs random (meaningless)
predictions — it is a placeholder to exercise the CoreML/Vision pipeline
end-to-end until a real trained model is available.

Usage:
    python3 scripts/generate_stub_model.py

Requires:
    pip3 install coremltools
"""
import coremltools as ct
from coremltools.models.neural_network import NeuralNetworkBuilder
from coremltools.models import datatypes
import numpy as np

labels = [
    "gyoza", "xiaolongbao", "pierogi", "empanada",
    "momo", "ravioli", "wonton", "samosa", "not_dumpling"
]

input_dim = 3 * 224 * 224
num_classes = len(labels)

# Build a minimal neural network classifier.
# NeuralNetworkBuilder with mode='classifier' replaced the removed
# NeuralNetworkClassifierBuilder in coremltools >= 7.
input_features = [("image", datatypes.Array(3, 224, 224))]
output_features = [("classLabelProbs", datatypes.Array(num_classes))]

builder = NeuralNetworkBuilder(
    input_features=input_features,
    output_features=output_features,
    mode="classifier"
)

# Random linear layer weights (stub — not trained)
weights = np.random.randn(num_classes, input_dim).astype(np.float32) * 0.01
bias = np.zeros(num_classes, dtype=np.float32)

builder.add_flatten(name="flatten", mode=0, input_name="image", output_name="flat")
builder.add_inner_product(
    name="classify",
    input_name="flat",
    output_name="labelProbs",
    input_channels=input_dim,
    output_channels=num_classes,
    W=weights,
    b=bias,
    has_bias=True
)
builder.add_softmax(name="softmax", input_name="labelProbs", output_name="classLabelProbs")

# Set class labels — makes this a classifier that outputs classLabel + probabilities dict
builder.set_class_labels(
    class_labels=labels,
    predicted_feature_name="classLabel",
    prediction_blob="classLabelProbs"
)

# Configure image input (RGB, 224x224)
spec = builder.spec
input_spec = spec.description.input[0]
input_spec.type.imageType.colorSpace = ct.proto.FeatureTypes_pb2.ImageFeatureType.RGB
input_spec.type.imageType.width = 224
input_spec.type.imageType.height = 224

model = ct.models.MLModel(spec)
model.save("DumplingNotDumpling/Models/DumplingClassifier.mlmodel")
print(f"Stub model saved with {num_classes} classes: {labels}")
