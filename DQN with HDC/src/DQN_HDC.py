import torch
import torch.nn as nn
import torch.optim as optim
import torch.nn.functional as F
import gym
import numpy as np
from collections import deque
import random
import sys

class ReplayBuffer:
    def __init__(self, buffer_size, batch_size):
        self.memory = deque(maxlen=buffer_size)
        self.batch_size = batch_size

    def add(self, experience):
        self.memory.append(experience)

    def sample(self):
        experiences = random.sample(self.memory, self.batch_size)
        states, actions, rewards, next_states, dones = zip(*experiences)
        return states, actions, rewards, next_states, dones

    def __len__(self):
        return len(self.memory)

class QNetwork(nn.Module):
    def __init__(self, state_size, action_size, fc1_units=64, fc2_units=128, fc3_units=64):
        super(QNetwork, self).__init__()
        self.fc1 = nn.Linear(state_size, fc1_units)
        self.fc2 = nn.Linear(fc1_units, fc2_units)
        self.fc3 = nn.Linear(fc2_units, fc3_units)
        self.fc4 = nn.Linear(fc3_units, action_size)

    def forward(self, state):
        x = F.relu(self.fc1(state))
        x = F.relu(self.fc2(x))
        x = F.relu(self.fc3(x))
        return self.fc4(x)

class QNetworkFHRR(nn.Module):
    def __init__(self, state_dim, action_dim, hyper_dim):
        super(QNetworkFHRR, self).__init__()
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.hyper_dim = hyper_dim
        self.register_buffer('state_projection', self.random_projection_matrix(state_dim, hyper_dim))
        self.register_buffer('action_vectors', self.normalize_angles(torch.randn(action_dim, hyper_dim)))
        self.q_hypervector = nn.Parameter(self.normalize_angles(torch.randn(hyper_dim)))
        self.scaling_factor = nn.Parameter(torch.tensor(1.0))  
        self.bias = nn.Parameter(torch.tensor(0.0))
        
    def forward(self, state):
        state_vector = self.project_to_angles(state, self.state_projection)
        state_action_vectors = self.bind(state_vector.unsqueeze(1), self.action_vectors)
        unbound_vectors = self.unbind(self.q_hypervector, state_action_vectors)
        similarity = self.FHRR_similarity(unbound_vectors, self.action_vectors[0])
        q_values = self.scaling_factor * similarity + self.bias
        return q_values

    def bind(self, x, y):
        return self.normalize_angles(x + y)  # Binding angles is addition

    def unbind(self, b, y):
        return self.normalize_angles(b - y)  # Unbinding angles is subtraction

    @staticmethod
    def normalize_angles(angle):
        return (angle + torch.pi) % (2 * torch.pi) - torch.pi

    def project_to_angles(self, x, projection_matrix):
        projected = torch.matmul(x, projection_matrix.T)
        return self.normalize_angles(projected)

    def FHRR_similarity(self, hv1, hv2):
        cos_sim = torch.cos(hv1 - hv2)
        return torch.sum(cos_sim, dim=-1)

    @staticmethod
    def random_projection_matrix(original_dim, target_dim):
        return torch.randn(target_dim, original_dim)
    
# Function to save the model
def save_model(model, path):
    torch.save(model.state_dict(), path)

# Function to load the model
def load_model(model, path):
    model.load_state_dict(torch.load(path))
    model.eval()

# Function to test the trained model
def test_model(env, model, num_episodes=100):
    total_rewards = []
    device = next(model.parameters()).device
    for episode in range(num_episodes):
        state = env.reset()
        if isinstance(state, tuple):
            state = state[0]
        done = False
        total_reward = 0

        while not done:
            state_tensor = torch.tensor(state, dtype=torch.float32).to(device)
            q_values = model(state_tensor.unsqueeze(0))
            action = torch.argmax(q_values).item()
            next_state, reward, terminated, truncated, _ = env.step(action)
            if isinstance(next_state, tuple):
                next_state = next_state[0]

            state = next_state
            total_reward += reward
            done = terminated or truncated

        total_rewards.append(total_reward)
        print(f"\nTest Episode {episode + 1}/{num_episodes}, Total Reward: {total_reward}")
        sys.stdout.flush()

    average_reward = np.mean(total_rewards)
    print(f"Average Reward over {num_episodes} episodes: {average_reward}")
    return average_reward

# Training function with experience replay
def train_model(env, model, optimizer, buffer, num_episodes=3000, gamma=0.99, epsilon_start=1.0, epsilon_min=0.01, epsilon_decay=0.995, save_path="best_q_model.pth"):
    rolling_window_rewards = deque(maxlen=100)
    rolling_window_losses = deque(maxlen=100)
    
    epsilon = epsilon_start
    
    device = next(model.parameters()).device

    for episode in range(num_episodes):
        state = env.reset()
        if isinstance(state, tuple):
            state = state[0]
        done = False
        total_reward = 0
        episode_loss = 0

        while not done:
            state_tensor = torch.tensor(state, dtype=torch.float32).to(device)
            if random.random() < epsilon:
                action = env.action_space.sample()
            else:
                with torch.no_grad():
                    q_values = model(state_tensor.unsqueeze(0)).squeeze()
                    action = torch.argmax(q_values).item()

            next_state, reward, terminated, truncated, _ = env.step(action)
            if isinstance(next_state, tuple):
                next_state = next_state[0]
            next_state_tensor = torch.tensor(next_state, dtype=torch.float32).to(device)
            buffer.add((state_tensor, action, reward, next_state_tensor, terminated or truncated))

            if len(buffer) >= buffer.batch_size:
                experiences = buffer.sample()
                states, actions, rewards, next_states, dones = experiences

                states = torch.stack(states).to(device).float()
                actions = torch.tensor(actions).to(device).unsqueeze(1).long()
                rewards = torch.tensor(rewards).to(device).unsqueeze(1).float()
                next_states = torch.stack(next_states).to(device).float()
                dones = torch.tensor(dones).to(device).unsqueeze(1).float()

                q_targets_next = model(next_states).detach().max(1)[0].unsqueeze(1)
                q_targets = rewards + (gamma * q_targets_next * (1 - dones))
                q_expected = model(states).gather(1, actions)

                loss = F.huber_loss(q_expected, q_targets, delta=1.0)

                optimizer.zero_grad()
                loss.backward()
                torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1)
            
                optimizer.step()

                episode_loss += loss.item()

            state = next_state
            total_reward += reward
            done = terminated or truncated

        rolling_window_rewards.append(total_reward)
        rolling_window_losses.append(episode_loss)
        rolling_avg_reward = np.mean(rolling_window_rewards)
        rolling_avg_loss = np.mean(rolling_window_losses)

        epsilon = max(epsilon_min, epsilon_decay * epsilon)

        print(f'\rEpisode {episode}\tAverage Score: {rolling_avg_reward:.2f}\tAverage Loss: {rolling_avg_loss:.2f}', end="")
        sys.stdout.flush()
        if episode % 100 == 0:
            print(f'\rEpisode {episode}\tAverage Score: {rolling_avg_reward:.2f}\tAverage Loss: {rolling_avg_loss:.2f}')
            sys.stdout.flush()

        if rolling_avg_reward >= 200.0:
            print(f'\nEnvironment solved in {episode - 100} episodes!\tAverage Score: {rolling_avg_reward:.2f}\tAverage Loss: {rolling_avg_loss:.2f}')
            sys.stdout.flush()
            save_model(model, save_path)
            break

# Initialize the environment and the Q-function
env = gym.make("LunarLander-v2")
state_dim = env.observation_space.shape[0]
action_dim = env.action_space.n

buffer_size = 100000
batch_size = 64
buffer = ReplayBuffer(buffer_size, batch_size)
HDC = True  # Use hyperdimensional computing
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

if HDC:
    hyper_dim = 10000
    # Adam FHRR lr: 1e-4 10000  buffer: 64 is working game solved in ~ 917 episode
    model = QNetworkFHRR(state_dim, action_dim, hyper_dim)
else:
    # Adam  lr: 1e-4 buffer: 64 is working game solved in ~ 400 episode
    model = QNetwork(state_dim, action_dim, fc1_units=64, fc2_units=128, fc3_units=64)

model.to(device)

optimizer = optim.Adam(model.parameters(), lr=1e-4)

# Train the model
train_model(env, model, optimizer, buffer, num_episodes=50000, save_path="FHRR.pth")

# Test the best model
env = gym.make("LunarLander-v2", render_mode="human")

load_model(model, "FHRR.pth")

test_model(env, model)
