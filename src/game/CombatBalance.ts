// Current slice values; physical / magical scaling remains a design proposal.
export const PLAYER_STATS = { maxHealth: 100, moveSpeed: 220, hurtDuration: 0.12, protectionDuration: 0.6 } as const;
export const ENEMY_STATS = { maxHealth: 60, damage: 20, moveSpeed: 120, attackRange: 70, warning: 0.45, swing: 0.10, recovery: 0.65, deathFade: 0.6 } as const;
export const ATTACK_STATS = {
  normal: { damage: 15, knockDistance: 14, knockDuration: 0.10 },
  pierce: { damage: 40, knockDistance: 36, knockDuration: 0.14 },
  rain: { damage: 15, knockDistance: 8, knockDuration: 0.08 },
} as const;
