import argparse

import gym
from stable_baselines import PPO2
from stable_baselines import SAC
from stable_baselines import TRPO
from stable_baselines.common.vec_env import DummyVecEnv


def run(env_name, algorithm, seed):
    env_name_map = {
        'halfcheetah': 'HalfCheetah-v2',
        'hopper': 'Hopper-v2',
        'ant': 'Ant-v2',
        'walker': 'Walker-v2'
    }
    env = DummyVecEnv([lambda: gym.make(env_name_map[env_name])])

    if algorithm == 'ppo':
        model = PPO2('MlpPolicy', env, learning_rate=1e-3, verbose=1)
    elif algorithm == 'trpo':
        model = TRPO('MlpPolicy', env, max_kl=0.01, verbose=1)
    elif algorithm == 'sac':
        model = SAC('MlpPolicy', env, learning_rate=1e-3, verbose=1)
    else:
        raise NotImplementedError()

    filepath = '%s_%s_%d' % (env_name, algorithm, seed)
    model.learn(total_timesteps=100000, seed=seed)
    model.save(filepath)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pid", help="condor process id", default=0, type=int)
    args = parser.parse_args()

    run_setups = []
    for seed in range(3):
        for env_name in ['halfcheetah', 'hopper', 'ant', 'walker']:
            for algorithm in ['ppo', 'trpo', 'sac']:
                run_setups.append((env_name, algorithm, seed))

    env_name, algorithm, seed = run_setups[args.pid]
    print('============================')
    print('env_name: %s' % env_name)
    print('algorithm: %s' % algorithm)
    print('seed: %d' % seed)
    print('============================')
    run(env_name, algorithm, seed)
