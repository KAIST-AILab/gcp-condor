import multiprocessing

import os
import gym
import numpy as np
from stable_baselines import PPO2
from stable_baselines import SAC
from stable_baselines import TRPO
from stable_baselines.common import set_global_seeds
from stable_baselines.common.vec_env import SubprocVecEnv
from tqdm import tqdm


def make_vectorized_env(env_name, n_envs=multiprocessing.cpu_count()):
    env_name_map = {
        'halfcheetah': 'HalfCheetah-v2',
        'hopper': 'Hopper-v2',
        'ant': 'Ant-v2',
        'walker': 'Walker2d-v2'
    }

    def make_env(env_id, seed=0):
        def _init():
            env = gym.make(env_id)
            env.seed(seed)
            return env

        set_global_seeds(seed)
        return _init

    vec_env = SubprocVecEnv([make_env(env_name_map[env_name], i) for i in range(n_envs)])
    return vec_env


def evaluate_policy(vec_env, agent, num_episodes=30, deterministic=False):
    episode_rewards = []

    with tqdm(total=num_episodes, desc="policy_evaluation") as pbar:
        episode_reward = np.zeros(vec_env.num_envs)
        obs = vec_env.reset()
        while len(episode_rewards) < num_episodes:
            action, _ = agent.predict(obs, deterministic=deterministic)
            next_obs, reward, done, _ = vec_env.step(action)

            episode_reward = episode_reward + reward
            if np.count_nonzero(done) > 0:
                episode_rewards += list(episode_reward[done])
                episode_reward[done] = 0
                pbar.update(np.count_nonzero(done))

            obs = next_obs

        episode_rewards = np.array(episode_rewards)

    mu = np.mean(episode_rewards)
    ste = np.std(episode_rewards) / np.sqrt(len(episode_rewards))

    return mu, ste


if __name__ == "__main__":
    for seed in range(3):
        for env_name in ['halfcheetah', 'hopper', 'ant', 'walker']:
            vec_env = make_vectorized_env(env_name)

            for algorithm in ['ppo', 'trpo', 'sac']:
                model_filepath = '%s_%s_%d.pkl' % (env_name, algorithm, seed)
                if not os.path.exists(model_filepath):
                    print("'%s' does not exists." % model_filepath)
                    continue

                if algorithm == 'ppo':
                    model = PPO2.load(model_filepath, vec_env)
                elif algorithm == 'trpo':
                    model = TRPO.load(model_filepath, vec_env)
                elif algorithm == 'sac':
                    model = SAC.load(model_filepath, vec_env)
                else:
                    raise NotImplementedError()

                result_mean, result_ste = evaluate_policy(vec_env, model)
                print("env=%s,algorithm=%s,seed=%d: %f +- %f" % (env_name, algorithm, seed, result_mean, 2 * result_ste))
