import { openDB } from 'idb'
import type { AppData } from '../core/models/radio'
import { cloneAppData } from '../core/models/radio'

const DB_NAME = 'senhaix-8800pro-web'
const STORE = 'backups'

export interface BackupRecord {
  id: string
  title: string
  createdAt: string
  reason: string
  data: AppData
}

async function database() {
  return openDB(DB_NAME, 1, {
    upgrade(db) {
      db.createObjectStore(STORE, { keyPath: 'id' })
    },
  })
}

export async function saveBackup(data: AppData, reason: string) {
  const db = await database()
  const createdAt = new Date().toISOString()
  const record: BackupRecord = {
    id: crypto.randomUUID(),
    title: `8800Pro-${createdAt.replace(/[:.]/g, '-')}`,
    createdAt,
    reason,
    data: cloneAppData(data),
  }
  await db.put(STORE, record)
  return record
}

export async function listBackups() {
  const db = await database()
  const records = (await db.getAll(STORE)) as BackupRecord[]
  return records.sort((a, b) => b.createdAt.localeCompare(a.createdAt))
}

export async function deleteBackup(id: string) {
  const db = await database()
  await db.delete(STORE, id)
}
