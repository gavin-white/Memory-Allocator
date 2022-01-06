#define _DEFAULT_SOURCE 1
#define _BSD_SOURCE 1
#include <stdio.h>
#include <unistd.h>

#define BLOCK_SIZE sizeof(block_t)

typedef struct block {
  size_t size;        // The size of the block in bytes
  struct block *next; // The next block in the linked list
  int free;           // Whether the block is free (1) or not (0)
} block_t;

block_t* head = NULL;

void *altmalloc(size_t s) {
  block_t* curr = head;
  block_t* min = NULL;
  block_t* last = NULL;
  while (curr != NULL) {
    if (curr->free == 1 && curr->size >= s) {
      if (min == NULL || curr->size < min->size) {
        min = curr;
      }
    }
    if (curr->next == NULL) {
      last = curr;
    }
    curr = curr->next;
  }

  if (min == NULL) {
    block_t * p;
    p = (block_t*) sbrk(s + BLOCK_SIZE);
    if (p == (void *) -1) {
      return NULL;
    }
    if (last != NULL) {
      last->next = p;
    } else {
      head = p;
    }
    p->size = s + BLOCK_SIZE; p->next = NULL; p->free = 0;
    return p + BLOCK_SIZE;
  } else {
    min->free = 0;
    return min + BLOCK_SIZE;
  }
}

void *altcalloc(size_t nmemb, size_t s) {
  void * p;
  p = altmalloc(nmemb * s);

  if (p == (void *) -1) {
    return NULL;
  }
  
  memset(p, 0, nmemb * s);
  
  return p;
}

void *altrealloc(void *ptr, size_t s) {
  block_t * p = ptr - BLOCK_SIZE;
  if (p->size <= s) {
    return ptr;
  }

  void *new_ptr = altmalloc(s);
  memcpy(new_ptr, ptr, p->size);
  return new_ptr;
}

void altfree(void *ptr) {
  ((block_t *) (ptr - BLOCK_SIZE))->free = 1;
}
