import numpy as np
import argparse
import gym


def run(env_name, algorithm, seed):
    env = gym.make(env_name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pid", help="condor process id", default=0, type=int)
    args = parser.parse_args()

    run_setups = []
    for seed in range(3):
        for env_name in ['HalfCheetah-v2', 'Hopper-v2', 'Ant-v2', 'Walker-v2']:
            for algorithm in ['ppo', 'trpo', 'sac']:
                run_setups.append((env_name, algorithm, seed))

    env_name, algorithm, seed = run_setups[args.pid]
    print('============================')
    print('env_name: %s' % env_name)
    print('algorithm: %s' % algorithm)
    print('seed: %d' % seed)
    print('============================')
    run(env_name, algorithm, seed)
