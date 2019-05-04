// TinyDNN.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include <ctime>
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <cmath>

const int traint_counts = 700;
const int valid_counts = 300;
const int test_counts = 100;
const int MAX = 100;

float sigmoid(float val)
{
	//return val > 0.000001f ? val : 0.0f;
	return 1 / (1 + exp(-val));
}

float sigmoid_derivative_dmy(float val)
{
	return (val) * (1 - val);
}

float* softmax(float *output, float *input, int count) {
	float max = 0.0;
	float sum = 0.0;
	for (int k = 0; k < count; ++k) {
		if (max < input[k]) {
			max = input[k];
		}
	}

	for (int j = 0; j < count; ++j) {
		sum += output[j] = exp(input[j] - max);
	}

	for (int i = 0; i < count; ++i) {
		output[i] /= sum;
	}
	return output;
}

float cross_entropy(char *ones, float *probs, int count) {
	float ce = 0.0f;
	for (int i = 0; i < count; i++) {
		if (probs[i] > 0.000001f) { // large than zero
			if (ones[i] == 1) {
				ce -= log(probs[i]);
			}
			else {
				ce -= log(1 - probs[i]);
			}
		}
	}
	return ce;
}

void one_hot(char *ones, int label) {
	// 0: 10, 1: 01
	*ones = *(ones + 1) = 0;
	*(ones + label) = 1;
}

float vector_multiple(float* weight, float* val, int count) {
	float sum = 0.0f;
	for (int i = 0; i < count; i++) {
		sum += weight[i] * val[i];
	}
	return sum;
}

int arg_max(float *val, int count) {
	int c = 0;
	float max = 0.0f;
	for (int i = 0; i < count; i++) {
		if (val[i] > max) {
			max = val[i];
			c = i;
		}
	}
	return c;
}

namespace dexp {

	class Layer {

	public:
		int _inputs_count;
		int _nodes_count;
		std::vector<float*> _weightss;
		float* _output;
		float* _deltas;

	public:
		Layer(int inputs_count, int nodes_count) {
			_inputs_count = inputs_count;
			_nodes_count = nodes_count;

			_deltas = new float[_nodes_count];
			_output = new float[_nodes_count];
			for (int i = 0; i < _nodes_count; i++) {
				float* weights = new float[_inputs_count];
				for (int j = 0; j < _inputs_count; j++) {
					weights[j] = 0.0f;
				}
				_weightss.push_back(weights);
			}
		}
		~Layer()
		{
			for (int i = 0; i < _nodes_count; i++) {
				delete _weightss[i];
			}
			delete _output;
			delete _deltas;
		}
		float* calculate(float* input) {
			for (int i = 0; i < _nodes_count; i++) {
				float node_ouput = sigmoid(vector_multiple(_weightss[i], input, _inputs_count));
				_output[i] = node_ouput;
			}
			return _output;
		}
		void output() {
			for (int i = 0; i < _nodes_count; i++) {
				for (int j = 0; j < _inputs_count; j++) {
					std::cout << _weightss[i][j] << ", ";
				}
				std::cout << std::endl;
			}
		}
	};

	// Use sigmoid activation function for simplicity
	class DNN {

	private:
		int _input_numbers, _output_number, _epoch = 100;
		float _learning_rate = 0.003f;
		std::vector<Layer*> _layers;
		float _input[10];
		char* _expect_ones;


	public:
		DNN(int input_numbers, int output_number) {
			_input_numbers = input_numbers;
			_output_number = output_number;
			_expect_ones = new char[_output_number];
			Layer* layer0 = new Layer(input_numbers, 20);
			Layer* layer1 = new Layer(20, 20);
			Layer* layer2 = new Layer(20, output_number);
			_layers.push_back(layer0);
			_layers.push_back(layer1);
			_layers.push_back(layer2);
		}
		~DNN() {
			for (unsigned int i = 0; i <= _layers.size() - 1; i++) {
				delete _layers[i];
			}
			delete _expect_ones;
		}

		float* feed_forward(float* input, int dimension) {
			for (unsigned int i = 0; i <= _layers.size() - 1; i++) {
				input = _layers[i]->calculate(input);
			}
			return input;
		}

		void back_propogate(float* input, char* ones) {
			// use the one hot encoding for the final layer output
			float error[MAX];
			Layer* layer = _layers[_layers.size() - 1];
			for (int i = 0; i < layer->_nodes_count; i++) {
				error[i] = (ones[i] == 1 ? 1.0f : 0.0f) - layer->_output[i];
			}

			// back order to generate error
			for (int j = (int)_layers.size() - 1; j >= 0; j--) {
				Layer* layer = _layers[j];
				for (int k = 0; k < layer->_nodes_count; k++) {
					layer->_deltas[k] = error[k] * sigmoid_derivative_dmy(layer->_output[k]);
				}

				// How much error did the previous layer pass to the current layer, Prev = Cur_Dalta * Cur_Weight?
				if (j >= 1) {
					for (int m = 0; m < layer->_inputs_count; m++) {
						error[m] = 0.0f;
						for (int n = 0; n < layer->_nodes_count; n++) {
							error[m] += layer->_weightss[n][m] * layer->_deltas[n];
						}
					}
				}
			}

			// adjust weight based on input & delta we got
			for (unsigned p = 0; p < _layers.size(); p++) {
				Layer* layer = _layers[p];
				for (int q = 0; q < layer->_nodes_count; q++) {
					for (int r = 0; r < layer->_inputs_count; r++) {
						layer->_weightss[q][r] += this->_learning_rate * layer->_deltas[q] * input[r];
						if (r == layer->_inputs_count) {
							layer->_weightss[q][r] += this->_learning_rate * layer->_deltas[q];
						}
					}
				}

				// change input for next layer
				input = layer->_output;
			}
		}

		void output() {
			for (unsigned p = 0; p < _layers.size(); p++) {
				Layer* layer = _layers[p];
				std::cout << "Output weight for layer " << p << std::endl;
				layer->output();
			}
			std::cout << std::endl;
		}

		float test(int valid_set[][11], int set_size = 0, bool is_test = false) {
			float* labels_probs = new float[_output_number];
			int rc = 0;
			for (int i = 0; i < set_size; i++) {
				int* data = valid_set[i];

				for (int j = 0; j < 10; j++) {
					_input[j] = data[j] / 1.0f;
				}

				float* dnn_output = feed_forward(_input, 10);
				softmax(labels_probs, dnn_output, _output_number);

				if (is_test) {
					//std::cout << "Predict=[" << labels_probs[0] << "," << labels_probs[1] << "], Expect=" << data[10] << std::endl;
				}

				if (arg_max(labels_probs, _output_number) == data[10]) {
					rc++;
				}
			}
			delete labels_probs;
			return rc * 1.0f / set_size;
		}

		void train(int data[11], int valid_set[][11] = NULL, int set_size = 0) {
			for (int j = 0; j < 10; j++) {
				_input[j] = data[j] / 1.0f;
			}
			one_hot(_expect_ones, data[10]);

			float* labels_probs = new float[_output_number];
			for (int i = 0; i < _epoch; i++) {
				float* dnn_output = feed_forward(_input, 10);
				softmax(labels_probs, dnn_output, _output_number);

				float loss = cross_entropy(_expect_ones, labels_probs, _output_number);
				back_propogate(_input, _expect_ones);
				//std::cout << "Croos entropy" << loss << std::endl;
			}
			if (valid_set != NULL) {
				//std::cout << "Validation accuracy:" << test(valid_set, valid_counts, false) << std::endl;
			}
			delete labels_probs;
		}
	};
}

int TRAINT_SET[traint_counts][11];
int VALID_SET[valid_counts][11];
int TEST_SET[test_counts][11];

void init(int matrix[][11], int count) {
	for (int i = 0; i < count; i++) {
		int sum = 0;
		for (int j = 0; j < 10; j++) {
			sum += matrix[i][j] = rand() % 10;
		}
		if (sum >= 75) {
			matrix[i][10] = 3;
		}
		else if (sum >= 50) {
			matrix[i][10] = 2;
		}
		else if (sum >= 25) {
			matrix[i][10] = 1;
		}
		else {
			matrix[i][10] = 0;
		}
	}
}

int main()
{
	srand((unsigned int)time(0));

	init(TRAINT_SET, traint_counts);
	init(VALID_SET, valid_counts);
	init(TEST_SET, test_counts);

	dexp::DNN dnn(10, 4);

	dnn.output();

	for (int i = 0; i < traint_counts; i++) {
		dnn.train(TRAINT_SET[i], VALID_SET, valid_counts);
	}

	dnn.output();



	std::cout << "Test accuracy:" << dnn.test(TEST_SET, test_counts, true) << std::endl;
	std::cout << "Hello DNN!\n";
}


