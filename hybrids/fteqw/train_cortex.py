from stable_baselines3 import PPO

from cortex_env import QuakeCortexEnv


def main() -> None:
    env = QuakeCortexEnv(host="127.0.0.1", port=26000)
    model = PPO("MlpPolicy", env, verbose=1)

    print("Cortex: waiting for Quake TCP stream...")
    print("Quake cvars: `pr_enable_uriget 1; cortex_use_tcp 1; cortex_enable_controls 1`")

    model.learn(total_timesteps=100_000)
    model.save("cortex_v1")

    print("Cortex: training complete.")


if __name__ == "__main__":
    main()

