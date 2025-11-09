export function serializeUser (user) {
  if (!user) return null
  return {
    id: user._id?.toString?.() ?? user._id,
    appleId: user.appleId,
    name: user.name ?? null,
    email: user.email ?? null,
    role: user.role ?? null,
    familyId: user.familyId ? user.familyId.toString() : null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  }
}

export function serializeFamily (family) {
  if (!family) return null
  return {
    id: family._id?.toString?.() ?? family._id,
    name: family.name,
    joinCode: family.joinCode,
    members: family.members?.map(member => member.toString()) ?? [],
    createdAt: family.createdAt,
    updatedAt: family.updatedAt
  }
}

