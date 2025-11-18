import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import App from './App'

describe('App', () => {
  it('renders the main heading', () => {
    render(<App />)
    
    expect(screen.getByRole('heading', { name: /depa finder/i })).toBeInTheDocument()
  })

  it('displays the description', () => {
    render(<App />)
    
    expect(screen.getByText(/rental listing scraper with real-time notifications/i)).toBeInTheDocument()
  })

  it('has interactive counter button', () => {
    render(<App />)
    
    const button = screen.getByRole('button', { name: /count is 0/i })
    expect(button).toBeInTheDocument()
  })

  it('shows spec-kit guidance', () => {
    render(<App />)
    
    expect(screen.getByText(/start by creating specifications/i)).toBeInTheDocument()
    expect(screen.getByText('/speckit.specify')).toBeInTheDocument()
  })
})
